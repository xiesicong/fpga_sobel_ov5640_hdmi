`timescale  1ns/1ns


module  i2c_ctrl
#(
    parameter   DEVICE_ADDR     =   7'b1010_000     ,   //i2c设备地址
    parameter   SYS_CLK_FREQ    =   26'd50_000_000  ,   //输入系统时钟频率
    parameter   SCL_FREQ        =   18'd250_000         //i2c设备scl时钟频率
)
(
    input   wire            sys_clk     ,   //输入系统时钟,50MHz
    input   wire            sys_rst_n   ,   //输入复位信号,低电平有效
    input   wire            wr_en       ,   //输入写使能信号
    input   wire            rd_en       ,   //输入读使能信号
    input   wire            i2c_start   ,   //输入i2c触发信号
    input   wire            addr_num    ,   //输入i2c字节地址字节数
    input   wire    [15:0]  byte_addr   ,   //输入i2c字节地址
    input   wire    [7:0]   wr_data     ,   //输入i2c设备数据

    output  reg             i2c_clk     ,   //i2c驱动时钟
    output  reg             i2c_end     ,   //i2c一次读/写操作完成
    output  reg     [7:0]   rd_data     ,   //输出i2c设备读取数据
    output  reg             i2c_scl     ,   //输出至i2c设备的串行时钟信号scl
    inout   wire            i2c_sda         //输出至i2c设备的串行数据信号sda
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//
// parameter define
parameter   CNT_CLK_MAX     =   (SYS_CLK_FREQ/SCL_FREQ) >> 2'd3   ;   //cnt_clk计数器计数最大值

parameter   CNT_START_MAX   =   8'd100; //cnt_start计数器计数最大值

parameter   IDLE            =   4'd00,  //初始状态
            START_1         =   4'd01,  //开始状态1
            SEND_D_ADDR     =   4'd02,  //设备地址写入状态 + 控制写
            ACK_1           =   4'd03,  //应答状态1
            SEND_B_ADDR_H   =   4'd04,  //字节地址高八位写入状态
            ACK_2           =   4'd05,  //应答状态2
            SEND_B_ADDR_L   =   4'd06,  //字节地址低八位写入状态
            ACK_3           =   4'd07,  //应答状态3
            WR_DATA         =   4'd08,  //写数据状态
            ACK_4           =   4'd09,  //应答状态4
            START_2         =   4'd10,  //开始状态2
            SEND_RD_ADDR    =   4'd11,  //设备地址写入状态 + 控制读
            ACK_5           =   4'd12,  //应答状态5
            RD_DATA         =   4'd13,  //读数据状态
            N_ACK           =   4'd14,  //非应答状态
            STOP            =   4'd15;  //结束状态

// wire  define
wire            sda_in          ;   //sda输入数据寄存
wire            sda_en          ;   //sda数据写入使能信号

// reg   define
reg     [7:0]   cnt_clk         ;   //系统时钟计数器,控制生成clk_i2c时钟信号
reg     [3:0]   state           ;   //状态机状态
reg             cnt_i2c_clk_en  ;   //cnt_i2c_clk计数器使能信号
reg     [1:0]   cnt_i2c_clk     ;   //clk_i2c时钟计数器,控制生成cnt_bit信号
reg     [2:0]   cnt_bit         ;   //sda比特计数器
reg             ack             ;   //应答信号
reg             i2c_sda_reg     ;   //sda数据缓存
reg     [7:0]   rd_data_reg     ;   //自i2c设备读出数据

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//
// cnt_clk:系统时钟计数器,控制生成clk_i2c时钟信号
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_clk <=  8'd0;
    else    if(cnt_clk == CNT_CLK_MAX - 1'b1)
        cnt_clk <=  8'd0;
    else
        cnt_clk <=  cnt_clk + 1'b1;

// i2c_clk:i2c驱动时钟
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        i2c_clk <=  1'b1;
    else    if(cnt_clk == CNT_CLK_MAX - 1'b1)
        i2c_clk <=  ~i2c_clk;

// cnt_i2c_clk_en:cnt_i2c_clk计数器使能信号
always@(posedge i2c_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_i2c_clk_en  <=  1'b0;
    else    if((state == STOP) && (cnt_bit == 3'd3) &&(cnt_i2c_clk == 3))
        cnt_i2c_clk_en  <=  1'b0;
    else    if(i2c_start == 1'b1)
        cnt_i2c_clk_en  <=  1'b1;

// cnt_i2c_clk:i2c_clk时钟计数器,控制生成cnt_bit信号
always@(posedge i2c_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_i2c_clk <=  2'd0;
    else    if(cnt_i2c_clk_en == 1'b1)
        cnt_i2c_clk <=  cnt_i2c_clk + 1'b1;

// cnt_bit:sda比特计数器
always@(posedge i2c_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_bit <=  3'd0;
    else    if((state == IDLE) || (state == START_1) || (state == START_2)
                || (state == ACK_1) || (state == ACK_2) || (state == ACK_3)
                || (state == ACK_4) || (state == ACK_5) || (state == N_ACK))
        cnt_bit <=  3'd0;
    else    if((cnt_bit == 3'd7) && (cnt_i2c_clk == 2'd3))
        cnt_bit <=  3'd0;
    else    if((cnt_i2c_clk == 2'd3) && (state != IDLE))
        cnt_bit <=  cnt_bit + 1'b1;

// state:状态机状态跳转
always@(posedge i2c_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        state   <=  IDLE;
    else    case(state)
        IDLE:
            if(i2c_start == 1'b1)
                state   <=  START_1;
            else
                state   <=  state;
        START_1:
            if(cnt_i2c_clk == 3)
                state   <=  SEND_D_ADDR;
            else
                state   <=  state;
        SEND_D_ADDR:
            if((cnt_bit == 3'd7) &&(cnt_i2c_clk == 3))
                state   <=  ACK_1;
            else
                state   <=  state;
        ACK_1:
            if((cnt_i2c_clk == 3) && (ack == 1'b0))
                begin
                    if(addr_num == 1'b1)
                        state   <=  SEND_B_ADDR_H;
                    else
                        state   <=  SEND_B_ADDR_L;
                end
             else
                state   <=  state;
        SEND_B_ADDR_H:
            if((cnt_bit == 3'd7) &&(cnt_i2c_clk == 3))
                state   <=  ACK_2;
            else
                state   <=  state;
        ACK_2:
            if((cnt_i2c_clk == 3) && (ack == 1'b0))
                state   <=  SEND_B_ADDR_L;
            else
                state   <=  state;
        SEND_B_ADDR_L:
            if((cnt_bit == 3'd7) && (cnt_i2c_clk == 3))
                state   <=  ACK_3;
            else
                state   <=  state;
        ACK_3:
            if((cnt_i2c_clk == 3) && (ack == 1'b0))
                begin
                    if(wr_en == 1'b1)
                        state   <=  WR_DATA;
                    else    if(rd_en == 1'b1)
                        state   <=  START_2;
                    else
                        state   <=  state;
                end
             else
                state   <=  state;
        WR_DATA:
            if((cnt_bit == 3'd7) &&(cnt_i2c_clk == 3))
                state   <=  ACK_4;
            else
                state   <=  state;
        ACK_4:
            if((cnt_i2c_clk == 3) && (ack == 1'b0))
                state   <=  STOP;
            else
                state   <=  state;
        START_2:
            if(cnt_i2c_clk == 3)
                state   <=  SEND_RD_ADDR;
            else
                state   <=  state;
        SEND_RD_ADDR:
            if((cnt_bit == 3'd7) &&(cnt_i2c_clk == 3))
                state   <=  ACK_5;
            else
                state   <=  state;
        ACK_5:
            if((cnt_i2c_clk == 3) && (ack == 1'b0))
                state   <=  RD_DATA;
            else
                state   <=  state;
        RD_DATA:
            if((cnt_bit == 3'd7) &&(cnt_i2c_clk == 3))
                state   <=  N_ACK;
            else
                state   <=  state;
        N_ACK:
            if(cnt_i2c_clk == 3)
                state   <=  STOP;
            else
                state   <=  state;
        STOP:
            if((cnt_bit == 3'd3) &&(cnt_i2c_clk == 3))
                state   <=  IDLE;
            else
                state   <=  state;
        default:    state   <=  IDLE;
    endcase

// ack:应答信号
always@(*)
    case    (state)
        IDLE,START_1,SEND_D_ADDR,SEND_B_ADDR_H,SEND_B_ADDR_L,
        WR_DATA,START_2,SEND_RD_ADDR,RD_DATA,N_ACK:
            ack <=  1'b1;
        ACK_1,ACK_2,ACK_3,ACK_4,ACK_5:
            if(cnt_i2c_clk == 2'd0)
                ack <=  sda_in;//1'b0;//
            else
                ack <=  ack;
        default:    ack <=  1'b1;
    endcase

// i2c_scl:输出至i2c设备的串行时钟信号scl
always@(*)
    case    (state)
        IDLE:
            i2c_scl <=  1'b1;
        START_1:
            if(cnt_i2c_clk == 2'd3)
                i2c_scl <=  1'b0;
            else
                i2c_scl <=  1'b1;
        SEND_D_ADDR,ACK_1,SEND_B_ADDR_H,ACK_2,SEND_B_ADDR_L,
        ACK_3,WR_DATA,ACK_4,START_2,SEND_RD_ADDR,ACK_5,RD_DATA,N_ACK:
            if((cnt_i2c_clk == 2'd1) || (cnt_i2c_clk == 2'd2))
                i2c_scl <=  1'b1;
            else
                i2c_scl <=  1'b0;
        STOP:
            if((cnt_bit == 3'd0) &&(cnt_i2c_clk == 2'd0))
                i2c_scl <=  1'b0;
            else
                i2c_scl <=  1'b1;
        default:    i2c_scl <=  1'b1;
    endcase

// i2c_sda_reg:sda数据缓存
always@(*)
    case    (state)
        IDLE:
            begin
                i2c_sda_reg <=  1'b1;
                rd_data_reg <=  8'd0;
            end
        START_1:
            if(cnt_i2c_clk <= 2'd0)
                i2c_sda_reg <=  1'b1;
            else
                i2c_sda_reg <=  1'b0;
        SEND_D_ADDR:
            if(cnt_bit <= 3'd6)
                i2c_sda_reg <=  DEVICE_ADDR[6 - cnt_bit];
            else
                i2c_sda_reg <=  1'b0;
        ACK_1:
            i2c_sda_reg <=  1'b1;
        SEND_B_ADDR_H:
            i2c_sda_reg <=  byte_addr[15 - cnt_bit];
        ACK_2:
            i2c_sda_reg <=  1'b1;
        SEND_B_ADDR_L:
            i2c_sda_reg <=  byte_addr[7 - cnt_bit];
        ACK_3:
            i2c_sda_reg <=  1'b1;
        WR_DATA:
            i2c_sda_reg <=  wr_data[7 - cnt_bit];
        ACK_4:
            i2c_sda_reg <=  1'b1;
        START_2:
            if(cnt_i2c_clk <= 2'd1)
                i2c_sda_reg <=  1'b1;
            else
                i2c_sda_reg <=  1'b0;
        SEND_RD_ADDR:
            if(cnt_bit <= 3'd6)
                i2c_sda_reg <=  DEVICE_ADDR[6 - cnt_bit];
            else
                i2c_sda_reg <=  1'b1;
        ACK_5:
            i2c_sda_reg <=  1'b1;
        RD_DATA:
            if(cnt_i2c_clk  == 2'd2)
                rd_data_reg[7 - cnt_bit]    <=  sda_in;
            else
                rd_data_reg <=  rd_data_reg;
        N_ACK:
            i2c_sda_reg <=  1'b1;
        STOP:
            if((cnt_bit == 3'd0) && (cnt_i2c_clk < 2'd3))
                i2c_sda_reg <=  1'b0;
            else
                i2c_sda_reg <=  1'b1;
        default:
            begin
                i2c_sda_reg <=  1'b1;
                rd_data_reg <=  rd_data_reg;
            end
    endcase

// rd_data:自i2c设备读出数据
always@(posedge i2c_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        rd_data <=  8'd0;
    else    if((state == RD_DATA) && (cnt_bit == 3'd7) && (cnt_i2c_clk == 2'd3))
        rd_data <=  rd_data_reg;

// i2c_end:一次读/写结束信号
always@(posedge i2c_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        i2c_end <=  1'b0;
    else    if((state == STOP) && (cnt_bit == 3'd3) &&(cnt_i2c_clk == 3))
        i2c_end <=  1'b1;
    else
        i2c_end <=  1'b0;

// sda_in:sda输入数据寄存
assign  sda_in = i2c_sda;
// sda_en:sda数据写入使能信号
assign  sda_en = ((state == RD_DATA) || (state == ACK_1) || (state == ACK_2)
                    || (state == ACK_3) || (state == ACK_4) || (state == ACK_5))
                    ? 1'b0 : 1'b1;
// i2c_sda:输出至i2c设备的串行数据信号sda
assign  i2c_sda = (sda_en == 1'b1) ? i2c_sda_reg : 1'bz;

endmodule
