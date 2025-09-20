// Code your design here
module uart_tx
  #(parameter clk_freq=1000000,
    parameter baud_rate=9600)
  (input clk,
   input rst,
   input newd,
   input [7:0] tx_d,
   output reg tx,
   output reg tx_done
  );
  
  localparam clkcount=(clk_freq/baud_rate);
  
  int count=0;
  reg uclk=0;
  typedef enum bit[1:0]{idle=2'b00,start=2'b01,transfer=2'b10,done=2'b11} state_type;
  state_type state=idle;
  //uart_clk_generation
  
  always@(posedge clk)
    begin
      if(count<clkcount/2)
        begin
          count<=count+1;
        end
      else begin
        count<=0;
        uclk<=~uclk;
      end
    end
  reg [7:0] din;
  int countc=0;
  always@(posedge uclk)
    begin
      if(rst)begin
        state<=idle;
      end
      else begin
        case(state)
          idle:begin
            if(newd==1'b1)
              begin
                state<=start;
                tx<=0;
                din<=tx_d;
              end
            else
              begin
                state<=idle;
                tx<=1;
                countc<=0;
                tx_done<=0;
              end
          end
          start:begin
            if(countc<=7)
              begin
                tx<=din[countc];
                countc<=countc+1;
              end
            else begin
              countc<=0;
              tx_done<=1'b1;
              tx<=1'b1;

              state<=idle;
            end
          end
          default:state<=idle;
        endcase
      end
    end
endmodule
//uart_receiver


module uart_rx #(parameter clk_freq=1000000,
                 parameter baud_rate=9600)
  (input clk,
   input rst,
   input rx,
   output reg [7:0] rx_d,
   output reg rx_done
  );
  
  localparam clkcount=(clk_freq/baud_rate);
  
  typedef enum bit{ detect_start=1'b0,received=1'b1} state_type;
  state_type state=detect_start;
  
  int count=0;
  int countc=0;
  reg uclk=0;
  always@(posedge clk)
    begin
      if(count<=clkcount/2)begin
        count<=count+1;
      end
      else
        begin
          count<=0;
          uclk<=~uclk;
        end
    end
  
  
  always@(posedge uclk)
    begin
      if(rst)begin
        state<=detect_start;
      end
      else begin
        case(state)
          detect_start:begin
            if(rx==1'b0)begin
              state<=received;
            end
            else begin
              state<=detect_start;
              rx_done<=1'b0;
            end
          end
          received:begin
            if(countc<=7)
              begin
                rx_d<={rx,rx_d[7:1]};
                countc=countc+1;
              end
            else begin
              countc<=0;
              rx_done<=1;
              state<=detect_start;
            end
          end
      endcase
      end
    end
endmodule

module top#(parameter clk_freq=1000000,
            baud_rate=9600)
  (input clk,
   input rst,
   input rx,
   input newd,
   input [7:0]tx_d,
   output [7:0] rx_data,
   output tx,
   output done_tx,
   output done_rx
          );
  uart_tx #(clk_freq,baud_rate) uut1(clk,rst,newd,tx_d,tx,done_tx);
  uart_rx #(clk_freq,baud_rate) uut2(clk,rst,rx,rx_data,done_rx);
endmodule
  
  
   


            
          
          
  
  
            
          
          
            
      
      
      