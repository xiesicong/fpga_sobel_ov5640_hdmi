`timescale  1ns/1ns

module axi_master_write
(
  input           ARESETN    , //axi复位
  input           ACLK       , //axi总时钟
//axi4写通道地址通道
  output [3:0]  M_AXI_AWID   , //写地址ID，用来标志一组写信号
  output [31:0] M_AXI_AWADDR , //写地址，给出一次写突发传输的写地址
  output [7:0]  M_AXI_AWLEN  , //突发长度，给出突发传输的次数  
  output [2:0]  M_AXI_AWSIZE , //突发大小，给出每次突发传输的字节数  
  output [1:0]  M_AXI_AWBURST, //突发类型  
  output        M_AXI_AWLOCK , //总线锁信号，可提供操作的原子性  
  output [3:0]  M_AXI_AWCACHE, //内存类型，表明一次传输是怎样通过系统的  
  output [2:0]  M_AXI_AWPROT , //保护类型，表明一次传输的特权级及安全等级  
  output [3:0]  M_AXI_AWQOS  , //质量服务QoS     
  output        M_AXI_AWVALID, //有效信号，表明此通道的地址控制信号有效
  input         M_AXI_AWREADY, //表明“从”可以接收地址和对应的控制信号
//axi4写通道数据通道
  output [63:0] M_AXI_WDATA  , //写数据
  output [7:0]  M_AXI_WSTRB  , //写数据有效的字节线
  output        M_AXI_WLAST  , //表明此次传输是最后一个突发传输
  output        M_AXI_WVALID , //写有效，表明此次写有效
  input         M_AXI_WREADY , //表明从机可以接收写数据
//axi4写通道应答通道
  input [3:0]   M_AXI_BID    , //写响应ID TAG
  input [1:0]   M_AXI_BRESP  , //写响应，表明写传输的状态
  input         M_AXI_BVALID , //写响应有效
  output        M_AXI_BREADY , //表明主机能够接收写响应
  //用户端信号
  input         WR_START     , //写突发触发信号
  input [31:0]  WR_ADRS      , //地址  
  input [9:0]  WR_LEN        , //长度
  output        WR_READY     , //写空闲
  output        WR_FIFO_RE   , //连接到写fifo的读使能
  input [63:0]  WR_FIFO_DATA , //连接到fifo的读数据
  output        WR_DONE        //完成一次突发
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//

localparam S_WR_IDLE  = 3'd0;//写空闲
localparam S_WA_WAIT  = 3'd1;//写地址等待
localparam S_WA_START = 3'd2;//写地址
localparam S_WD_WAIT  = 3'd3;//写数据等待
localparam S_WD_PROC  = 3'd4;//写数据循环
localparam S_WR_WAIT  = 3'd5;//接受写应答
localparam S_WR_DONE  = 3'd6;//写结束
//reg define  
reg [2:0]   wr_state   ; //状态寄存器
reg [31:0]  reg_wr_adrs; //地址寄存器
reg         reg_awvalid; //地址有效握手信号
reg         reg_wvalid ; //数据有效握手信号
reg         reg_w_last ; //传输最后一个数据
reg [7:0]   reg_w_len  ; //突发长度最大256，实测128最佳
reg [7:0]   reg_w_stb  ;

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//

//写完成信号的写状态完成
assign WR_DONE = (wr_state == S_WR_DONE);
//写fifo的读使能为axi数据握手成功
assign WR_FIFO_RE         = ((reg_wvalid & M_AXI_WREADY ));
//只有一个主机，可随意设置
assign M_AXI_AWID         = 4'b1111;
//把地址赋予总线
assign M_AXI_AWADDR[31:0] = reg_wr_adrs[31:0];
//一次突发传输1长度
assign M_AXI_AWLEN[7:0]   = WR_LEN-'d1;
//表示AXI总线每个数据宽度是8字节，64位
assign M_AXI_AWSIZE[2:0]  = 3'b011;
//01代表地址递增，10代表递减
assign M_AXI_AWBURST[1:0] = 2'b01; 
assign M_AXI_AWLOCK       = 1'b0;
assign M_AXI_AWCACHE[3:0] = 4'b0010;
assign M_AXI_AWPROT[2:0]  = 3'b000;
assign M_AXI_AWQOS[3:0]   = 4'b0000;
//地址握手信号AWVALID
assign M_AXI_AWVALID      = reg_awvalid;
//fifo数据赋予总线
assign M_AXI_WDATA[63:0]  = WR_FIFO_DATA[63:0];
assign M_AXI_WSTRB[7:0]   = 8'hFF;
//写到最后一个数据
assign M_AXI_WLAST        =(reg_w_len[7:0] == 8'd0)?'b1:'b0;
//数据握手信号WVALID
assign M_AXI_WVALID       = reg_wvalid;
//这个信号是告诉AXI我收到你的应答
assign M_AXI_BREADY       = M_AXI_BVALID;
//axi状态机空闲信号
assign WR_READY           = (wr_state == S_WR_IDLE)?1'b1:1'b0;

//axi写过程状态机
  always @(posedge ACLK or negedge ARESETN) begin
    if(!ARESETN) begin
      wr_state            <= S_WR_IDLE;
      reg_wr_adrs[31:0]   <= 32'd0;
      reg_awvalid         <= 1'b0;
      reg_wvalid          <= 1'b0;
      reg_w_last          <= 1'b0;
      reg_w_len[7:0]      <= 8'd0;
      
  end else begin
      case(wr_state)
        S_WR_IDLE: begin //写空闲
          if(WR_START) begin //触发写过程
            wr_state          <= S_WA_WAIT;
            reg_wr_adrs[31:0] <= WR_ADRS[31:0];
          end
          reg_awvalid         <= 1'b0;
          reg_wvalid          <= 1'b0;
          reg_w_len[7:0]      <= 8'd0;
        end
        S_WA_WAIT: begin//写地址等待
          wr_state        <= S_WA_START;//等待一个周期
        end
        S_WA_START: begin
          wr_state        <= S_WD_WAIT;//写数据等待
          reg_awvalid     <= 1'b1; //拉高地址有效信号 
          reg_wvalid      <= 1'b1;//拉高数据有效信号
        end
        S_WD_WAIT: begin
          if(M_AXI_AWREADY) begin//等待写地址就绪
            wr_state        <= S_WD_PROC;
            reg_w_len<=WR_LEN-'d1;//127代表128个长度，0代表1个长度
            reg_awvalid     <= 1'b0;
          end
        end
        S_WD_PROC: begin//等待AXI写数据就绪信号
          if(M_AXI_WREADY) begin//拉高了就可以输出fifo使能信号开始读
            
            if(reg_w_len[7:0] == 8'd0) begin//完成数据写过程
              wr_state        <= S_WR_WAIT;
              reg_wvalid      <= 1'b0;//此信号告诉AXI总线我正在写数据有效
              reg_w_last<='b1;
              //读到最后一个数据，拉高这个标志信号告诉AXI总线这是最后一个
              //如果不拉高传输不会成功
            end           
            else begin
              reg_w_len[7:0]  <= reg_w_len[7:0] -8'd1;
            end
          end
        end
        S_WR_WAIT: begin//等待写的AXI应答信号
          reg_w_last<='b0;
          //M_AXI_BVALID拉高表示写成功，然后状态机完成一次突发传输
          if(M_AXI_BVALID) begin
              wr_state          <= S_WR_DONE;
          end
        end
        S_WR_DONE: begin //写完成           
            wr_state <= S_WR_IDLE;
          end
        
        default: begin
          wr_state <= S_WR_IDLE;
        end
      endcase
      end
  end

endmodule

