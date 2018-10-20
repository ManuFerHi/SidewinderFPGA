`timescale 1ns / 1ps


/* This file is part of JT12.

 
	JT12 program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	JT12 program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with JT12.  If not, see <http://www.gnu.org/licenses/>.

	Based on Sauraen VHDL version of OPN/OPN2, which is based on die shots.

	Author: Jose Tejada Gomez. Twitter: @topapate
	Version: 1.0
	Date: 27-1-2017	

*/
// altera message_off 10030

module jt12_exprom
(
	input [4:0] addr,
	input clk, 
	output reg [44:0] exp
);

	reg [44:0] explut_jt51[31:0];
	initial
	begin
	explut_jt51[0] <= 45'b111110101011010110001011010000010010111011011;
	explut_jt51[1] <= 45'b111101010011010101000011001100101110110101011;
	explut_jt51[2] <= 45'b111011111011010011110111001000110010101110011;
	explut_jt51[3] <= 45'b111010100101010010101111000100110010101000011;
	explut_jt51[4] <= 45'b111001001101010001100111000000110010100001011;
	explut_jt51[5] <= 45'b110111111011010000011110111101010010011011011;
	explut_jt51[6] <= 45'b110110100011001111010110111001010010010100100;
	explut_jt51[7] <= 45'b110101001011001110001110110101110010001110011;
	explut_jt51[8] <= 45'b110011111011001101000110110001110010001000011;
	explut_jt51[9] <= 45'b110010100011001011111110101110010010000010011;
	explut_jt51[10] <= 45'b110001010011001010111010101010010001111011011;
	explut_jt51[11] <= 45'b101111111011001001110010100110110001110101011;
	explut_jt51[12] <= 45'b101110101011001000101010100011001101101111011;
	explut_jt51[13] <= 45'b101101010101000111100110011111010001101001011;
	explut_jt51[14] <= 45'b101100000011000110100010011011110001100011011;
	explut_jt51[15] <= 45'b101010110011000101011110011000010001011101011;
	explut_jt51[16] <= 45'b101001100011000100011010010100101101010111011;
	explut_jt51[17] <= 45'b101000010011000011010010010001001101010001011;
	explut_jt51[18] <= 45'b100111000011000010010010001101101101001011011;
	explut_jt51[19] <= 45'b100101110011000001001110001010001101000101011;
	explut_jt51[20] <= 45'b100100100011000000001010000110010000111111011;
	explut_jt51[21] <= 45'b100011010010111111001010000011001100111001011;
	explut_jt51[22] <= 45'b100010000010111110000101111111101100110011011;
	explut_jt51[23] <= 45'b100000110010111101000001111100001100101101011;
	explut_jt51[24] <= 45'b011111101010111100000001111000101100101000010;
	explut_jt51[25] <= 45'b011110011010111011000001110101001100100010011;
	explut_jt51[26] <= 45'b011101001010111010000001110001110000011100011;
	explut_jt51[27] <= 45'b011100000010111001000001101110010000010110011;
	explut_jt51[28] <= 45'b011010110010111000000001101011001100010001011;
	explut_jt51[29] <= 45'b011001101010110111000001100111101100001011011;
	explut_jt51[30] <= 45'b011000100000110110000001100100010000000110010;
	explut_jt51[31] <= 45'b010111010010110101000001100001001100000000011;
	end

	always @ (posedge clk) 
		exp <= explut_jt51[addr];

endmodule
