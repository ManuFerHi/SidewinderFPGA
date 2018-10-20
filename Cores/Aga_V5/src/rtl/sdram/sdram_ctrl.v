//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
//                                                                          //
// Copyright (c) 2009/2011 Tobias Gubener                                   //
// Subdesign fAMpIGA by TobiFlex                                            //
//                                                                          //
// This source file is free software: you can redistribute it and/or modify //
// it under the terms of the GNU General Public License as published        //
// by the Free Software Foundation, either version 3 of the License, or     //
// (at your option) any later version.                                      //
//                                                                          //
// This source file is distributed in the hope that it will be useful,      //
// but WITHOUT ANY WARRANTY; without even the implied warranty of           //
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            //
// GNU General Public License for more details.                             //
//                                                                          //
// You should have received a copy of the GNU General Public License        //
// along with this program.  If not, see <http://www.gnu.org/licenses/>.    //
//                                                                          //
//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
//
// RK:
// 2013-02-12 - converted to Verilog
//            - cleanup
//            - code simplification
//            - added two-lines cache
// jepalza (julio-18): soporte para memoria AGA con CHIP48 (4 bancos)


module sdram_ctrl(
  // system
  input  wire           sysclk,
  input  wire           c_7m,
  input  wire           reset_in,
  input  wire           cache_rst,
  output wire           reset_out,
  // temp - cache control
  input wire            cache_ena,
  // sdram
  output reg  [ 13-1:0] sdaddr,
  output reg  [  4-1:0] sd_cs,
  output reg  [  2-1:0] ba,
  output reg            sd_we,
  output reg            sd_ras,
  output reg            sd_cas,
  output reg  [  2-1:0] dqm,
  inout  wire [ 16-1:0] sdata,
  // host
  input  wire           host_cs,
  input  wire [ 25-1:0] host_adr,
  input  wire           host_we,
  input  wire [  4-1:0] host_bs,
  input  wire [ 32-1:0] host_wdat,
  output reg  [ 32-1:0] host_rdat,
  output wire           host_ack,
  // chip
  input  wire    [23:1] chipAddr,
  input  wire           chipL,
  input  wire           chipU,
  input  wire           chipRW,
  input  wire           chip_dma,
  input  wire [ 16-1:0] chipWR,
  output reg  [ 16-1:0] chipRD,
  output wire [ 48-1:0] chip48, // jepalza
  // cpu
  input  wire    [24:1] cpuAddr,
  input  wire [  6-1:0] cpustate,
  input  wire           cpuL,
  input  wire           cpuU,
  input  wire           cpu_dma,
  input  wire [ 16-1:0] cpuWR,
  output wire [ 16-1:0] cpuRD,
  output reg            enaWRreg,
  output reg            ena7RDreg,
  output reg            ena7WRreg,
  output wire           cpuena
);


//// internal parameters ////
localparam [3:0]
  ph0 = 0,
  ph1 = 1,
  ph2 = 2,
  ph3 = 3,
  ph4 = 4,
  ph5 = 5,
  ph6 = 6,
  ph7 = 7,
  ph8 = 8,
  ph9 = 9,
  ph10 = 10,
  ph11 = 11,
  ph12 = 12,
  ph13 = 13,
  ph14 = 14,
  ph15 = 15;

parameter [1:0]
  nop = 0,
  ras = 1,
  cas = 2;


//// internal signals ////
reg  [  4-1:0] initstate;
reg  [  4-1:0] cas_sd_cs;
reg            cas_sd_ras;
reg            cas_sd_cas;
reg            cas_sd_we;
reg  [  2-1:0] cas_dqm;
reg            init_done;
reg  [ 16-1:0] datawr;
reg  [ 25-1:0] casaddr;
reg            sdwrite;
reg  [ 16-1:0] sdata_reg;
reg            hostCycle;
reg            cena;
reg  [ 64-1:0] ccache;
reg  [ 25-1:0] ccache_addr;
reg            ccache_fill;
reg            ccachehit;
reg  [  4-1:0] cvalid;
wire           cequal;
reg  [  2-1:0] cpustated;
reg  [ 16-1:0] cpuRDd;
reg  [  8-1:0] reset_cnt;
reg            reset;
reg            reset_sdstate;
reg            c_7md;
reg            c_7mdd;
reg            c_7mdr;
reg            cpuCycle;
reg            chipCycle;
reg  [  4-1:0] sdram_state;
wire [  2-1:0] pass;
wire [  4-1:0] tst_adr1;
wire [  4-1:0] tst_adr2;

// CPU states
//             [5]    [4:3]              [2]   [1:0]
// cpustate <= clkena&slower(1 downto 0)&ramcs&state
// [1:0] = state = 00-> fetch code 10->read data 11->write data 01->no memaccess


// --------------------------------
// Jepalza, nuevo, para que el AGA vea los cuatro bancos de memoria de video

reg  [16-1:0] chip48_1;
reg  [16-1:0] chip48_2;
reg  [16-1:0] chip48_3;

//// chip line read ////
always @ (posedge sysclk) begin
  if(chipCycle) begin
    case(sdram_state)
      ph9  : chipRD   <= #1 sdata_reg;
      ph10 : chip48_1 <= #1 sdata_reg;
      ph11 : chip48_2 <= #1 sdata_reg;
      ph12 : chip48_3 <= #1 sdata_reg;
    endcase
  end
end

assign chip48 = {chip48_1, chip48_2, chip48_3};

// hasta aqui, es nuevo
// --------------------------------



////////////////////////////////////////
// reset
////////////////////////////////////////

always @ (posedge sysclk or negedge reset_in) begin
  if (~reset_in) begin
    reset_cnt <= 8'b00000000;
    reset <= 1'b0;
    reset_sdstate <= 1'b0;
  end else begin
    if (reset_cnt == 8'b00101010) begin
      reset_sdstate <= 1'b1;
    end
    if (reset_cnt == 8'b10101010) begin
      if (sdram_state == ph15) begin
        reset <= 1'b1;
      end
    end else begin
      reset_cnt <= reset_cnt + 8'd1;
      reset <= 1'b0;
    end
  end
end

assign reset_out = init_done;


////////////////////////////////////////
// host access
////////////////////////////////////////
reg        host_write_ack;
reg [15:0] host_cache [3:0];
reg [24:3] host_cache_addr;
reg        host_cache_valid;
wire       host_cache_hit;
reg [2:1]  burst_addr;

assign host_ack = host_write_ack | host_cache_hit & !host_we & host_cs;

always @ (posedge sysclk or negedge reset) begin
  if (!reset)
    host_write_ack <= 0;
  else
    host_write_ack <= (sdram_state == ph5) & hostCycle & host_we;
end

always @(*) begin
  host_rdat[31:16] = host_cache[{host_adr[2],1'b0}];
  host_rdat[15:0]  = host_cache[{host_adr[2],1'b1}];
end

assign host_cache_hit = (host_cache_addr == host_adr[24:3]) & host_cache_valid;

always @ (posedge sysclk or negedge reset) begin
  if (!reset) begin
    host_cache_valid <= 0;
  end else if (!cas_sd_we) begin
    // Keep the cache coherent on writes
    if (sdram_state == ph5 && host_cache_addr == casaddr[24:3]) begin
      if (!dqm[1])
        host_cache[casaddr[2:1]][15:8] <= datawr[15:8];
      if (!dqm[0])
        host_cache[casaddr[2:1]][7:0] <= datawr[7:0];
    end
    if (sdram_state == ph6 && host_cache_addr == casaddr[24:3]) begin
      if (!dqm[1])
        host_cache[casaddr[2:1]+1][15:8] <= datawr[15:8];
      if (!dqm[0])
        host_cache[casaddr[2:1]+1][7:0] <= datawr[7:0];
    end
  end else if (hostCycle) begin
    // Refill cache
    if (sdram_state == ph2) begin
      burst_addr <= casaddr[2:1];
      host_cache_valid <= 0;
    end else if (sdram_state > ph7 && sdram_state < ph12) begin
      host_cache_addr <= casaddr[24:3];
      host_cache[burst_addr] <= sdata;
      burst_addr <= burst_addr + 1;
      if (sdram_state == ph11)
        host_cache_valid <= 1;
    end
  end
end

////////////////////////////////////////
// cpu cache
////////////////////////////////////////

// CPU bus register
reg     [24:1] cpuAddr_reg = 0;
reg  [  6-1:0] cpustate_reg = 0;
reg            cpuL_reg = 0;
reg            cpuU_reg = 0;
reg            cpu_dma_reg = 0;
reg  [ 16-1:0] cpuWR_reg = 0;

always @ (posedge sysclk) begin
  cpuWR_reg <= #1 cpuWR;
end

wire cache_ack;
assign cpuena = cache_ack || (cpustate[1:0] == 2'b01);

cpu_cache cpu_cache (
  // system
  .clk          (sysclk       ),
  .rst          (!(reset && cache_rst)),
  .cache_ena    (cache_ena    ),
  // cpu if
  .cpu_state    (cpustate     ),
  .cpu_adr      (cpuAddr      ),
  .cpu_bs       ({cpuU, cpuL} ),
  .cpu_dat_w    (cpuWR        ),
  .cpu_dat_r    (cpuRD        ),
  .cpu_ack      (cache_ack    ),
  // sdram if
  .sdr_state    (sdram_state  ),
  .sdr_adr      (casaddr      ),
  .sdr_cpucycle (cpuCycle     ),
  .sdr_cas      (cas_sd_cas   ),
  .sdr_dat_w    (             ),
  .sdr_dat_r    (sdata_reg    ),
  .sdr_cpu_act  (             )
);

////////////////////////////////////////
// chip cache
////////////////////////////////////////

// jepalza, anulo esto, por que lo he cambiado de formas, arriba, al principio
//reg  [ 16-1:0] chipRDd;
//
//always @ (posedge sysclk) begin
//  if ((sdram_state == ph9) && chipCycle)
//    chipRDd <= sdata_reg;
//end
//
//// chip cache read
//always @ (*) begin
//    chipRD = chipRDd;
//end


////////////////////////////////////////
// SDRAM control
////////////////////////////////////////

// clock mangling - TODO
always @ (negedge sysclk) begin
  c_7md <= c_7m;
end
always @ (posedge sysclk) begin
  c_7mdd <= c_7md;
  c_7mdr <= c_7md &  ~c_7mdd;
end

// SDRAM data I/O
assign sdata = (sdwrite) ? datawr : 16'bzzzzzzzzzzzzzzzz;

// read data reg
always @ (posedge sysclk) begin
  sdata_reg <= sdata;
end

// write data reg
always @ (posedge sysclk) begin
  if (sdram_state == ph2) begin
    if (chipCycle) begin
      datawr <= chipWR;
    end else if (cpuCycle) begin
      datawr <= cpuWR;
    end else begin
      datawr <= host_wdat[31:16];
    end
  end
  if (sdram_state == ph5 && hostCycle)
    datawr <= host_wdat[15:0];
end

// write / read control
always @ (posedge sysclk or negedge reset_sdstate) begin
  if (~reset_sdstate) begin
    sdwrite   <= 1'b0;
    enaWRreg  <= 1'b0;
    ena7RDreg <= 1'b0;
    ena7WRreg <= 1'b0;
  end else begin
    case (sdram_state) // LATENCY=3
      ph2 : begin
        sdwrite   <= 1'b1;
        enaWRreg  <= 1'b1;
        ena7RDreg <= 1'b0;
        ena7WRreg <= 1'b0;
      end
      ph3 : begin
        sdwrite   <= 1'b1;
        enaWRreg  <= 1'b0;
        ena7RDreg <= 1'b0;
        ena7WRreg <= 1'b0;
      end
      ph4 : begin
        sdwrite   <= 1'b1;
        enaWRreg  <= 1'b0;
        ena7RDreg <= 1'b0;
        ena7WRreg <= 1'b0;
      end
      ph5 : begin
        sdwrite   <= 1'b1;
        enaWRreg  <= 1'b0;
        ena7RDreg <= 1'b0;
        ena7WRreg <= 1'b0;
      end
      ph6 : begin
        sdwrite   <= 1'b0;
        enaWRreg  <= 1'b1;
        ena7RDreg <= 1'b1;
        ena7WRreg <= 1'b0;
      end
      ph10 : begin
        sdwrite   <= 1'b0;
        enaWRreg  <= 1'b1;
        ena7RDreg <= 1'b0;
        ena7WRreg <= 1'b0;
      end
      ph14 : begin
        sdwrite   <= 1'b0;
        enaWRreg  <= 1'b1;
        ena7RDreg <= 1'b0;
        ena7WRreg <= 1'b1;
      end
      default : begin
        sdwrite   <= 1'b0;
        enaWRreg  <= 1'b0;
        ena7RDreg <= 1'b0;
        ena7WRreg <= 1'b0;
      end
    endcase
  end
end

// init counter
always @ (posedge sysclk or negedge reset) begin
  if (~reset) begin
    initstate <= {4{1'b0}};
    init_done <= 1'b0;
  end else begin
    case (sdram_state) // LATENCY=3
      ph15 : begin
        if (initstate != 4'b1111) begin
          initstate <= initstate + 4'd1;
        end else begin
          init_done <= 1'b1;
        end
      end
      default : begin
      end
    endcase
  end
end

// sdram state
always @ (posedge sysclk) begin
  if (c_7mdr) begin
    sdram_state <= ph2;
  end else begin
    case (sdram_state) // LATENCY=3
      ph0     : begin
        sdram_state <= ph1;
      end
      ph1     : begin
        sdram_state <= ph2;
      end
      ph2     : begin
        sdram_state <= ph3;
      end
      ph3     : begin
        sdram_state <= ph4;
      end
      ph4     : begin
        sdram_state <= ph5;
      end
      ph5     : begin
        sdram_state <= ph6;
      end
      ph6     : begin
        sdram_state <= ph7;
      end
      ph7     : begin
        sdram_state <= ph8;
      end
      ph8     : begin
        sdram_state <= ph9;
      end
      ph9     : begin
        sdram_state <= ph10;
      end
      ph10    : begin
        sdram_state <= ph11;
      end
      ph11    : begin
        sdram_state <= ph12;
      end
      ph12    : begin
        sdram_state <= ph13;
      end
      ph13    : begin
        sdram_state <= ph14;
      end
      ph14    : begin
        sdram_state <= ph15;
      end
      default : begin
        sdram_state <= ph0;
      end
    endcase
  end
end

wire cpu_cs = !cpustate[2] && !cpustate[5];

// sdram control
always @ (posedge sysclk) begin
  sd_cs  <= 4'b1111;
  sd_ras <= 1'b1;
  sd_cas <= 1'b1;
  sd_we  <= 1'b1;
  sdaddr <= 13'bxxxxxxxxxxxx;
  ba     <= 2'b00;
  dqm    <= 2'b00;
  if (!init_done) begin
    if (sdram_state == ph1) begin
      case (initstate)
      4'b0010 : begin
        //PRECHARGE
        sdaddr[10] <= 1'b1;
        //all banks
        sd_cs  <= 4'b0000;
        sd_ras <= 1'b0;
        sd_cas <= 1'b1;
        sd_we  <= 1'b0;
      end
      4'b0011,4'b0100,4'b0101,4'b0110,4'b0111,4'b1000,4'b1001,4'b1010,4'b1011,4'b1100 : begin
        //AUTOREFRESH
        sd_cs  <= 4'b0000;
        sd_ras <= 1'b0;
        sd_cas <= 1'b0;
        sd_we  <= 1'b1;
      end
      4'b1101 : begin
        //LOAD MODE REGISTER
        sd_cs  <= 4'b0000;
        sd_ras <= 1'b0;
        sd_cas <= 1'b0;
        sd_we  <= 1'b0;
        //sdaddr <= 12b001000100010; // BURST=4 LATENCY=2
        //sdaddr <= 13'b0001000110010; // BURST=4 LATENCY=3
        sdaddr <= 13'b0000000110010; // BURST=4 LATENCY=3, write burst
        //sdaddr <= 12'b001000110000; // noBURST LATENCY=3
      end
      default : begin
        // NOP
      end
      endcase
    end
  end else begin
    // time slot control
    if (sdram_state == ph1) begin
      cpuCycle   <= 1'b0;
      chipCycle  <= 1'b0;
      hostCycle  <= 1'b0;
      cas_sd_cs  <= 4'b1110;
      cas_sd_ras <= 1'b1;
      cas_sd_cas <= 1'b1;
      cas_sd_we  <= 1'b1;
      //if ((!(cctrl[0] && chip_cache_equal && &chip_cache_valid) && (!chip_dma)) || !chipRW) begin
      if (!chip_dma || !chipRW) begin
        // chip cycle
        chipCycle  <= 1'b1;
        sdaddr     <= chipAddr[21:9];
        ba         <= chipAddr[23:22];
        cas_dqm    <= {chipU,chipL};
        sd_cs      <= 4'b1110; // active
        sd_ras     <= 1'b0;
        casaddr    <= {1'b0,chipAddr,1'b0};
        cas_sd_cas <= 1'b0;
        cas_sd_we  <= chipRW;
      end else if (cpu_cs & !(cpuCycle & (host_cs & !host_ack))) begin
        // cpu cycle
        cpuCycle   <= 1'b1;
        sdaddr     <= cpuAddr[21:9];
        ba         <= cpuAddr[23:22];
        cas_dqm    <= {cpuU,cpuL};
        sd_cs      <= 4'b1110; // active
        sd_ras     <= 1'b0;
        casaddr    <= {cpuAddr[24:1],1'b0};
        cas_sd_cas <= 1'b0;
        cas_sd_we  <= ~cpustate[1] | ~cpustate[0];
      end else if (host_cs && !host_ack) begin
        // host cycle
        hostCycle  <= 1'b1;
        sdaddr     <= host_adr[21:9];
        ba         <= host_adr[23:22];
        cas_dqm    <= ~host_bs[3:2];
        sd_cs      <= 4'b1110; // active
        sd_ras     <= 1'b0;
        casaddr    <= host_adr;
        cas_sd_cas <= 1'b0;
        cas_sd_we  <= !host_we;
      end else begin
        // refresh cycle
        sd_cs      <= 4'b0000; // autorefresh
        sd_ras     <= 1'b0;
        sd_cas     <= 1'b0;
      end
    end
    if (sdram_state == ph4) begin
      sdaddr  <= {2'b00,1'b1,1'b0,casaddr[24],casaddr[8:1]}; // auto precharge
      ba      <= casaddr[23:22];
      sd_cs   <= cas_sd_cs;
      dqm     <= (!cas_sd_we) ? cas_dqm : 2'b00;
      sd_ras  <= cas_sd_ras;
      sd_cas  <= cas_sd_cas;
      sd_we   <= cas_sd_we;
    end
    if (sdram_state == ph5 && !cas_sd_we) begin
       dqm <= hostCycle ? ~host_bs[1:0] : 2'b11;
    end
    // Do not write the two last words in the write burst
    if ((sdram_state == ph6 || sdram_state == ph7) && !cas_sd_we) begin
       dqm <= 2'b11;
    end

  end
end

endmodule
