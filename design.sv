// Code your design here
// Code your design here
module spi_master(input clk,
                  input rst,
                  input newd,
                  input [7:0] din,
                  output reg cs,sclk,mosi
                 );
  
  typedef enum bit[1:0]{idle=2'b00,enable=2'b01,sent=2'b10,complete}state_type;
  state_type state=idle;
  
  int countc =0;
  int count=0;
  
  always@(posedge clk)
    begin
      if(rst==1'b1)begin
        sclk<=0;
        countc<=0;
      end
      else if(countc<10)begin
        countc=countc+1;
      end
      else begin
        countc<=0;
        sclk=~sclk;
      end
    end
  
  reg [7:0]temp;
  always@(posedge sclk)
    begin
      if(rst==1'b1)begin
        cs<=1'b1;
        mosi<=1'b0;
      end
      else begin
        case(state)
          idle:begin
            if(newd==1'b1) begin
              state<=sent;
              temp<=din;
              cs<=1'b0;
            end
            else begin
              state<=idle;
              cs<=1'b1;
            end
          end
          sent: begin
            if(count<=7)begin
              count<=count+1;
              mosi<=temp[count];
            end
            else begin
              count<=0;
              state<=idle;
              cs<=1'b1;
            end
          end
          default : state<=idle;
        endcase
      end
    end
endmodule
//------------------------------------------------
module spi_slave(input cs,
                 input sclk,
                 input mosi,
                 output [7:0] dout,
                 output reg done
                );
  
  typedef enum bit{detect_start=1'b0,received_data}state_type;
  state_type state=detect_start;
  int countt=0;
  reg [7:0] temp=8'h00;
  
  always@(posedge sclk)
    begin
      case(state)
          detect_start:begin
            done<=1'b0;
            if(cs==1'b0)begin
              state<=received_data;
            end
            else
              state<=detect_start;
          end
          received_data:begin
            if(countt<=7)begin
              temp <= {mosi,temp[7:1]};   // shift left, LSB-first input

              countt<=countt+1;
            end
            else begin
              countt<=0;
              done<=1'b1;
              state<=detect_start;
            end
          end
          default: state<=detect_start;
        endcase
    end
  
  assign dout=temp;
endmodule
//■■■■■■■■■■■■■■■■■■■
module top(input clk,
           input rst,
           input newd,
           input [7:0] din,
           output [7:0]dout,
           output done
          );
  wire cs,sclk,mosi;
  
  spi_master uut1(clk,rst,newd,din,cs,sclk,mosi);
  spi_slave uut2(cs,sclk,mosi,dout,done);
endmodule
              
              
                 
                 
            
  
        