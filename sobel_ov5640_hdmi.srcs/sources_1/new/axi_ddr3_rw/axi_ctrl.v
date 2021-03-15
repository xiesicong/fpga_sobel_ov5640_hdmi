`timescale 1ns / 1ps

module axi_ctrl
#(
parameter  DDR_WR_LEN=128,//写突发长度 128个64bit
parameter  DDR_RD_LEN=128//读突发长度 128个64bit

)
(
   input   wire        ui_clk     ,
   input   wire        ui_rst     ,
   input   wire        pingpang   ,//乒乓操作
   
   input   wire [31:0] wr_b_addr  ,   //写DDR首地址
   input   wire [31:0] wr_e_addr  ,   //写DDR末地址
   input   wire        user_wr_clk,   //写FIFO写时钟
   input   wire        data_wren  ,   //写FIFO写请求
   //写进fifo数据长度，可根据写fifo的写端口数据长度自行修改
   //写FIFO写数据 16位，此时用64位是为了兼容32,64位
   input   wire [63:0] data_wr    ,    
   input   wire        wr_rst     ,
   
   input   wire [31:0] rd_b_addr  ,   //读DDR首地址
   input   wire [31:0] rd_e_addr  ,   //读DDR末地址    
   input   wire        user_rd_clk,   //读FIFO读时钟
   input   wire        data_rden  ,   //读FIFO读请求  
   //读出fifo数据长度，可根据读fifo的读端口数据长度自行修改
   //读FIFO读数据,16位，此时用64位是为了兼容32,64位
   output  wire [63:0] data_rd    ,   
   input   wire        rd_rst     ,
   input   wire        read_enable,
      
   output  wire        wr_burst_req    , //写突发触发信号
   output  wire[31:0]  wr_burst_addr   , //地址  
   output  wire[9:0]   wr_burst_len    , //长度
   input   wire        wr_ready        , //写空闲
   input   wire        wr_fifo_re      , //连接到写fifo的读使能
   output  wire [63:0] wr_fifo_data    , //连接到fifo的读数据
   input   wire        wr_burst_finish , //完成一次突发
                                      
   output  wire        rd_burst_req    , //读突发触发信号
   output  wire[31:0]  rd_burst_addr   , //地址  
   output  wire[9:0]   rd_burst_len    ,  //长度
   input   wire        rd_ready        , //读空闲
   input   wire        rd_fifo_we      , //连接到读fifo的写使能
   input   wire[63:0]  rd_fifo_data    , //连接到读fifo的写数据
   input   wire        rd_burst_finish   //完成一次突发
   );
 
//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//
//reg define
reg       wr_burst_req_reg ; //写突发寄存器
reg [31:0]wr_burst_addr_reg; //写地址寄存器
reg [9:0] wr_burst_len_reg ; //写长度寄存器

reg       rd_burst_req_reg ; //读突发寄存器
reg [31:0]rd_burst_addr_reg; //读地址寄存器
reg [9:0] rd_burst_len_reg ; //读长度寄存器
//读写地址复位打拍寄存器
reg wr_rst_reg1;
reg wr_rst_reg2;
reg rd_rst_reg1;
reg rd_rst_reg2;

reg pingpang_reg;//乒乓操作指示寄存器

//wire define
//写fifo信号
wire        wr_fifo_wr_clk        ;
wire        wr_fifo_rd_clk        ;
wire [63:0] wr_fifo_din           ;
wire        wr_fifo_wr_en         ;
wire        wr_fifo_rd_en         ;
wire [63:0] wr_fifo_dout          ;
wire        wr_fifo_full          ;
wire        wr_fifo_almost_full   ;
wire        wr_fifo_empty         ;
wire        wr_fifo_almost_empty  ;
(*mark_debug="true"*)wire  [9:0] wr_fifo_rd_data_count ;
(*mark_debug="true"*)wire  [11:0] wr_fifo_wr_data_count ;

//读fifo信号
wire        rd_fifo_wr_clk        ;
wire        rd_fifo_rd_clk        ;
wire [63:0] rd_fifo_din           ;
wire        rd_fifo_wr_en         ;
wire        rd_fifo_rd_en         ;
wire [63:0] rd_fifo_dout          ;
wire        rd_fifo_full          ;
wire        rd_fifo_almost_full   ;
wire        rd_fifo_empty         ;
wire        rd_fifo_almost_empty  ;
wire  [11:0] rd_fifo_rd_data_count ;
wire  [9:0] rd_fifo_wr_data_count ;

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//

assign wr_burst_req  = wr_burst_req_reg;  //写突发请求
assign wr_burst_addr = wr_burst_addr_reg; //写地址
assign wr_burst_len  = DDR_WR_LEN;        //写长度

assign rd_burst_req  = rd_burst_req_reg;  //读突发请求
assign rd_burst_addr = rd_burst_addr_reg; //读地址
assign rd_burst_len  = DDR_RD_LEN;        //读长度

//写fifo写时钟位用户端时钟
assign wr_fifo_wr_clk = user_wr_clk;
//写fifo读时钟位axi总时钟
assign wr_fifo_rd_clk = ui_clk;
//写fifo非满为用户输入数据
assign wr_fifo_din    = data_wr;
//写fifo非满为用户输入数据使能
assign wr_fifo_wr_en  = data_wren;
//写fifo非空为axi写主机读取使能
assign wr_fifo_rd_en  = wr_fifo_re;
//写fifo非空为axi写主机读取数据
assign wr_fifo_data   = wr_fifo_dout;
//读fifo写时钟位axi读主机时钟
assign rd_fifo_wr_clk=ui_clk;
//读fifo读时钟位用户时钟
assign rd_fifo_rd_clk=user_rd_clk;
//读fifo读使能为用户使能
assign rd_fifo_rd_en =data_rden;
//读fifo读数据为用户使能
assign data_rd       =rd_fifo_dout;
//读fifo写使能为axi读主机写使能
assign rd_fifo_wr_en =rd_fifo_we;
//读fifo写使能为axi读主机写数据
assign rd_fifo_din   =rd_fifo_data;

//对写复位信号的跨时钟域打2拍
always@(posedge ui_clk or posedge ui_rst) begin
    if(ui_rst==1'b1)begin
        wr_rst_reg1<=1'b0;
        wr_rst_reg2<=1'b0;
    end
    else begin
        wr_rst_reg1<=wr_rst;
        wr_rst_reg2<=wr_rst_reg1;
    end

end

//对读复位信号的跨时钟域打2拍
always@(posedge ui_clk or posedge ui_rst) begin
    if(ui_rst==1'b1)begin
        rd_rst_reg1<=1'b0;
        rd_rst_reg2<=1'b0;
    end
    else begin
        rd_rst_reg1<=rd_rst;
        rd_rst_reg2<=rd_rst_reg1;
    end

end


//写burst请求产生
always@(posedge ui_clk or posedge ui_rst) begin
    if(ui_rst==1'b1)begin
        wr_burst_req_reg<=1'b0;
        
    end
    //fifo数据长度大于一次突发长度并且axi写空闲
    else if(wr_fifo_rd_data_count>=(DDR_WR_LEN-2) && wr_ready==1'b1 ) 
    begin 
        wr_burst_req_reg<=1'b1;      
    end
    else begin
        wr_burst_req_reg<=1'b0;
    end

end

//完成一次突发对地址进行相加
//相加地址长度=突发长度x8,64位等于8字节
//128*8=1024
always@(posedge ui_clk or posedge ui_rst) begin
    if(ui_rst==1'b1)begin
        wr_burst_addr_reg<=wr_b_addr;
        pingpang_reg<=1'b0;
        
    end
    //写复位信号上升沿
    else if(wr_rst_reg1&(~wr_rst_reg2)) begin
        wr_burst_addr_reg<=wr_b_addr;
    end 
    else if(wr_burst_finish==1'b1) begin
        wr_burst_addr_reg<=wr_burst_addr_reg+DDR_WR_LEN*8;
        //判断是否是乒乓操作
        if(pingpang==1'b1) begin
        //结束地址为2倍的接受地址，有两块区域
            if(wr_burst_addr_reg>=((wr_e_addr-wr_b_addr)*2+wr_b_addr-DDR_WR_LEN*8)) 
            begin
                wr_burst_addr_reg<=wr_b_addr;
            end
            //根据地址，pingpang_reg为0或者1
            //用于指示读操作与写操作地址不冲突
            if(wr_burst_addr_reg<wr_e_addr) begin
                pingpang_reg<=1'b0;
            end
            else begin
                pingpang_reg<=1'b1;
            end
        
        end
        //非乒乓操作
        else begin
            if(wr_burst_addr_reg>=(wr_e_addr-DDR_WR_LEN*8)) 
            begin
                wr_burst_addr_reg<=wr_b_addr;
            end
        end
    end
    else begin
        wr_burst_addr_reg<=wr_burst_addr_reg;
    end

end

//读burst请求产生
always@(posedge ui_clk or posedge ui_rst) begin
    if(ui_rst==1'b1)begin
        rd_burst_req_reg<=1'b0;
    end
    //fifo可写长度大于一次突发长度并且axi读空闲，fifo总长度1024
    else if(rd_fifo_wr_data_count<=(10'd1000-DDR_RD_LEN) 
            && rd_ready==1'b1 &&read_enable==1'b1) 
    begin
        rd_burst_req_reg<=1'b1;
    end
    else begin
        rd_burst_req_reg<=1'b0;
    end

end

//完成一次突发对地址进行相加
//相加地址长度=突发长度x8,64位等于8字节
//128*8=1024
always@(posedge ui_clk or posedge ui_rst) begin
    if(ui_rst==1'b1)begin
        if(pingpang==1'b1) rd_burst_addr_reg<=rd_e_addr;
        else rd_burst_addr_reg<=rd_b_addr;
    end
     else if(rd_rst_reg1&(~rd_rst_reg2)) begin
        rd_burst_addr_reg<=rd_b_addr;
    end 
    else if(rd_burst_finish==1'b1) begin
        rd_burst_addr_reg<=rd_burst_addr_reg+DDR_RD_LEN*8;//地址累加
        //乒乓操作
         if(pingpang==1'b1) begin
           //到达结束地址 
           if((rd_burst_addr_reg==(rd_e_addr-DDR_RD_LEN*8))||
              (rd_burst_addr_reg==((rd_e_addr-rd_b_addr)*2+rd_b_addr-DDR_RD_LEN*8))) 
           begin
                //根据写指示地址信号，对读信号进行复位
               if(pingpang_reg==1'b1) rd_burst_addr_reg<=rd_b_addr;
               else rd_burst_addr_reg<=rd_e_addr;
           end
                    
        end
        else begin  //非乒乓操作
            if(rd_burst_addr_reg>=(rd_e_addr-DDR_RD_LEN*8)) 
            begin
            rd_burst_addr_reg<=rd_b_addr;
            end
        end
    end
    else begin
        rd_burst_addr_reg<=rd_burst_addr_reg;
    end

end

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//

//------------- wr_fifo_inst -------------
//写fifo
wr_fifo wr_fifo_inst (
  .wr_rst(wr_rst||ui_rst), // 写复位
  .rd_rst(wr_rst||ui_rst), //读复位
  .wr_clk(wr_fifo_wr_clk), // 写时钟
  .rd_clk(wr_fifo_rd_clk), // 读时钟
  .din   (wr_fifo_din   ), // 外部写进fifo的数据 16位
  .wr_en (wr_fifo_wr_en ), // 写使能
  .rd_en (wr_fifo_rd_en ), // 读使能
  .dout  (wr_fifo_dout  ), // 输出给ddr的axi写数据，写进ddr 64位
  .full  (wr_fifo_full  ), // fifo满信号
  .almost_full  (wr_fifo_almost_full  ), //fifo几乎满信号
  .empty (wr_fifo_empty ), //fifo空信号 
  .almost_empty (wr_fifo_almost_empty ),
  .rd_data_count(wr_fifo_rd_data_count), // 可读数据个数
  .wr_data_count(wr_fifo_wr_data_count)  // 可写数据个数
);

//------------- rd_fifo_inst -------------
//读fifo
rd_fifo rd_fifo_inst (
  .wr_rst(rd_rst||ui_rst), // 写复位
  .rd_rst(rd_rst||ui_rst), //读复位
  .wr_clk(rd_fifo_wr_clk), // 写时钟
  .rd_clk(rd_fifo_rd_clk), // 读时钟
  .din   (rd_fifo_din   ), // ddr读出的数据，写进fifo 64位
  .wr_en (rd_fifo_wr_en ), // 写使能
  .rd_en (rd_fifo_rd_en ), // 读使能
  .dout  (rd_fifo_dout  ), // 最终我们读出的数据 64位
  .full  (rd_fifo_full  ), // fifo满信号
  .almost_full  (rd_fifo_almost_full  ),
  .empty (rd_fifo_empty ), //fifo几乎满信号
  .almost_empty (rd_fifo_almost_empty ),
  .rd_data_count(rd_fifo_rd_data_count), // 可读数据个数
  .wr_data_count(rd_fifo_wr_data_count)  // 可写数据个数
);

endmodule
