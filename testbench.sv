// Code your testbench here
// or browse Examples
interface uart_if;
  logic clk;
  logic rst;
  logic newd;
  logic rx;
  logic tx;
  logic [7:0] tx_d;
  logic [7:0] rx_data;
  logic done_tx;
  logic done_rx;
  logic uclktx;
  logic uclkrx;
endinterface

class transaction;
  rand bit[7:0] tx_d;
  typedef enum bit  {write = 1'b0 , read = 1'b1} oper_type;
  
  rand oper_type oper;
  bit newd;
  bit rx,tx,done_tx,done_rx;
  bit[7:0] rx_data;
  
  constraint oper_t{ oper dist{0:=50,1:=50};}
  
  function transaction copy();
    copy=new();
    copy.tx_d=this.tx_d;
    copy.newd=this.newd;
    copy.rx=this.rx;
    copy.tx=this.tx;
    copy.rx_data=this.rx_data;
    copy.done_tx=this.done_tx;
    copy.done_rx=this.done_rx;
    copy.oper=this.oper;
    
  endfunction
  
endclass

class generator;
  transaction t;
  mailbox#(transaction) mbx;
  mailbox#(transaction) hbx;
  event done;
  event next;
  event nexts;
  int count=0;
  
  function new(mailbox#(transaction) mbx);
    this.mbx=mbx;
    t=new();
  endfunction
  
  task run();
    repeat(count)begin
      assert(t.randomize())else $error("Randomization failed!");
      $display("[GEN]:sending data to driver...");
      $display("[GEN]:tx_data:[%0d]:newd:[%0d]",t.tx_d,t.newd);
      mbx.put(t.copy());
      @(next);
      @(nexts);
    end
    ->done;
  endtask
endclass

class driver;
  virtual uart_if f;
  transaction tc;
  mailbox#(transaction) mbx;
  mailbox#(bit[7:0]) hbx;
  event next;
  bit[7:0] datarx;
  
  function new(mailbox#(transaction) mbx,mailbox#(bit[7:0]) hbx);
    this.mbx=mbx;
    this.hbx=hbx;
  endfunction
  task reset();
    @(posedge f.uclktx);
    f.rst<=1'b1;
    f.newd<=1'b0;
    f.rx<=1'b1;
    f.tx<=1'b1;
    repeat(2)@(posedge f.uclktx);
    f.rst<=1'b0;
    $display("[DRV]:RESET DONE!");
    @(posedge f.uclktx);
  endtask
  task run();
    forever begin
      mbx.get(tc);
      if(tc.oper==1'b1) begin
        @(posedge f.uclktx);
        f.rst<=1'b0;
        f.rx<=1'b1;
        f.newd<=1'b1;
        f.tx_d<=tc.tx_d;
        @(posedge f.uclktx);
        f.newd<=1'b0;
        $display("[DRV]:Data received:tx_data:[%0d]",tc.tx_d);
        hbx.put(tc.tx_d);
        wait(f.done_tx==1'b1);
        ->next;
      end
      else if(tc.oper==1'b0)
        begin
          @(posedge f.uclkrx);
          f.rst<=0;
          f.newd<=1'b0;
          f.rx<=1'b0;
          @(posedge f.uclkrx);
          for(int i=0;i<=7;i++)
            begin
              @(posedge f.uclkrx);
              f.rx<=$urandom();
              datarx[i]<=f.rx;
            end
          $display("[DRV]:Data in receiver:[%0d]",datarx);
          hbx.put(datarx);
          wait(f.done_rx==1'b1);
          f.rx<=1'b1;
          ->next;
        end
    end
  endtask       
endclass

class monitor;
  virtual uart_if f;
  transaction td;
  mailbox#(bit[7:0]) mbx;
  bit[7:0] ubx;
  bit[7:0] sbx;
  
  function new(mailbox#(bit[7:0]) mbx);
    this.mbx=mbx;
  endfunction
  
  task run();
    forever begin
      @(posedge f.uclktx);
      if((f.newd==1'b1) && (f.rx==1'b1))
        begin
          @(posedge f.uclktx);
          for(int k=0;k<=7;k++)begin
            @(posedge f.uclktx);
            ubx[k]=f.tx;
          end
          @(posedge f.uclktx);
          mbx.put(ubx);
          $display("[MON]:transmitting:[%0d]",ubx);
        end
      else if((f.newd==1'b0) && (f.rx==1'b0))
        begin
          wait(f.done_rx==1'b1);
          sbx=f.rx_data;
          $display("[MON]:Data recevied from receiver:[%0d]",sbx);
          @(posedge f.uclkrx);
          mbx.put(sbx);         @(posedge f.uclkrx);
        end
    end
  endtask
      
endclass

class scoreboard;
  mailbox#(bit[7:0]) kbx;
  mailbox#(bit[7:0]) lbx;
  bit[7:0] j;
  bit[7:0] k;
  event nexts;
  
  function new(mailbox#(bit[7:0]) kbx,mailbox#(bit[7:0]) lbx);
    this.kbx=kbx;
    this.lbx=lbx;
  endfunction
  
  
  task run();
    forever begin
      kbx.get(j);
      lbx.get(k);
      if(j==k)begin
        $display("-------------------------");
        $display("[SCO]:Data Matched!");
        $display("--------------------------");
      end
      else begin 
        $display("--------------------------");
        $display("[SCO]: Data Missmatched!");
        $display("--------------------------");
      end
      ->nexts;
    end
  endtask
endclass

class environment;
  virtual uart_if f;
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  
  mailbox#(transaction) gdmbx;
  mailbox#(bit[7:0]) dgmbx;
  mailbox#(bit[7:0]) msmbx;
  event next;
  event nexts;
  
  function new( virtual uart_if f);
    gdmbx=new();
    dgmbx=new();
    msmbx=new();
    
    gen=new(gdmbx);
    drv=new(gdmbx,dgmbx);
    mon=new(msmbx);
    sco=new(msmbx,dgmbx);
    this.f=f;
    drv.f=this.f;
    mon.f=this.f;
    gen.next=next;
    drv.next=next;
    gen.nexts=nexts;
    sco.nexts=nexts;
    
  endfunction
  
  task pre_test();
    drv.reset();
  endtask
  
  task test();
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join
  endtask
  
  task post_test();
    @(gen.done);
    $finish();
  endtask
  
  task run();
    pre_test();
    fork
      test();
      post_test();
    join
  endtask
endclass

module topp;
  uart_if f();
  top #(1000000,9600)
  dut(f.clk,f.rst,f.rx,f.newd,f.tx_d,f.rx_data,f.tx,f.done_tx,f.done_rx);
  
  environment e;
  
  initial f.clk=0;
  always #10 f.clk=~f.clk;
  
  initial begin 
    e=new(f);
    e.gen.count=5;
    e.run();
  end
  
  assign f.uclktx=dut.uut1.uclk;
  assign f.uclkrx=dut.uut2.uclk;
endmodule
    
    
  
      
      
    
      
    
    
  