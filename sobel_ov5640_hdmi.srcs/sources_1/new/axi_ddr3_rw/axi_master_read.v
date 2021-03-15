`timescale  1ns/1ns

module axi_master_read
(
  input           ARESETN,//axi复位
  input           ACLK,  //axi时钟
//axi读通道写地址
  output [3:0]  M_AXI_ARID   , //读地址ID，用来标志一组写信号
  output [31:0] M_AXI_ARADDR , //读地址，给出一次写突发传输的读地址
  output [7:0]  M_AXI_ARLEN  , //突发长度，给出突发传输的次数
  output [2:0]  M_AXI_ARSIZE , //突发大小，给出每次突发传输的字节数
  output [1:0]  M_AXI_ARBURST, //突发类型
  output [1:0]  M_AXI_ARLOCK , //总线锁信号，可提供操作的原子性
  output [3:0]  M_AXI_ARCACHE, //内存类型，表明一次传输是怎样通过系统的
  output [2:0]  M_AXI_ARPROT , //保护类型，表明一次传输的特权级及安全等级
  output [3:0]  M_AXI_ARQOS  , //质量服务QOS
  output        M_AXI_ARVALID, //有效信号，表明此通道的地址控制信号有效
  input         M_AXI_ARREADY, //表明“从”可以接收地址和对应的控制信号
    
  //axi读通道读数据
  input [3:0]   M_AXI_RID   , //读ID tag
  input [63:0]  M_AXI_RDATA , //读数据
  input [1:0]   M_AXI_RRESP , //读响应，表明读传输的状态
  input         M_AXI_RLAST , //表明读突发的最后一次传输
  input         M_AXI_RVALID, //表明此通道信号有效
  output        M_AXI_RREADY, //表明主机能够接收读数据和响应信息
   //用户端fifo接口    
  input         RD_START    , //读突发触发信号
  input [31:0]  RD_ADRS     , //地址  
  input [9:0]   RD_LEN       , //长度
  output        RD_READY    , //读空闲
  output        RD_FIFO_WE  , //连接到读fifo的写使能
  output [63:0] RD_FIFO_DATA, //连接到读fifo的写数据
  output        RD_DONE       //完成一次突发
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//

//parameter  define
localparam S_RD_IDLE  = 3'd0; //读空闲
localparam S_RA_WAIT  = 3'd1; //读地址等待
localparam S_RA_START = 3'd2; //读地址
localparam S_RD_WAIT  = 3'd3; //读数据等待
localparam S_RD_PROC  = 3'd4; //读数据循环
localparam S_RD_DONE  = 3'd5; //写结束
//reg define                               
reg [2:0]   rd_state   ; //状态寄存器
reg [31:0]  reg_rd_adrs; //地址寄存器
reg [31:0]  reg_rd_len ; //突发长度寄存器
reg         reg_arvalid; //地址有效寄存器

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//

assign RD_DONE = (rd_state == S_RD_DONE) ;
assign M_AXI_ARID         = 4'b1111;//地址id
assign M_AXI_ARADDR[31:0] = reg_rd_adrs[31:0];//地址
assign M_AXI_ARLEN[7:0]   = RD_LEN-32'd1;//突发长度
assign M_AXI_ARSIZE[2:0]  = 3'b011;//表示AXI总线每个数据宽度是8字节，64位
assign M_AXI_ARBURST[1:0] = 2'b01;//地址递增方式传输
assign M_AXI_ARLOCK       = 1'b0;
assign M_AXI_ARCACHE[3:0] = 4'b0011;
assign M_AXI_ARPROT[2:0]  = 3'b000;
assign M_AXI_ARQOS[3:0]   = 4'b0000;
assign M_AXI_ARVALID      = reg_arvalid;
assign M_AXI_RREADY       = M_AXI_RVALID;
assign RD_READY           = (rd_state == S_RD_IDLE)?1'b1:1'b0;//写空闲
assign RD_FIFO_WE         = M_AXI_RVALID;//读fifo的写使能信号
assign RD_FIFO_DATA[63:0] = M_AXI_RDATA[63:0];//读fifo的写数据信号 

  // 读状态机
  always @(posedge ACLK or negedge ARESETN) begin
    if(!ARESETN) begin
      rd_state          <= S_RD_IDLE;
      reg_rd_adrs[31:0] <= 32'd0;
      reg_rd_len[31:0]  <= 32'd0;
      reg_arvalid       <= 1'b0;
    end else begin
      case(rd_state)
        S_RD_IDLE: begin//读空闲
          if(RD_START) begin//突发触发信号
            rd_state          <= S_RA_WAIT;
            reg_rd_adrs[31:0] <= RD_ADRS[31:0];
            reg_rd_len[31:0]  <= RD_LEN[9:0] -32'd1;
          end
          reg_arvalid     <= 1'b0;
        end
        S_RA_WAIT: begin//写地址等待
            rd_state          <= S_RA_START;
        end
        S_RA_START: begin//写地址
          rd_state          <= S_RD_WAIT;
          reg_arvalid       <= 1'b1;//拉高地址有效
        end
        S_RD_WAIT: begin //读取数据等待
          if(M_AXI_ARREADY) begin
            rd_state        <= S_RD_PROC;
            reg_arvalid     <= 1'b0;
          end
        end
        S_RD_PROC: begin //接受循环
          if(M_AXI_RVALID) begin //收到数据有效，握手成功
            if(M_AXI_RLAST) begin //收到最后一个数据
                rd_state<= S_RD_DONE;
            end
          end
        end
    S_RD_DONE:begin //接受接受
      rd_state          <= S_RD_IDLE;
    end
    endcase
    end
  end
   
endmodule