`timescale  1ns/1ns


module  hdmi_cfg
(
    input   wire            sys_clk     ,   //系统时钟,由iic模块传入
    input   wire            sys_rst_n   ,   //系统复位,低有效
    input   wire            cfg_end     ,   //单个寄存器配置完成

    output  reg             cfg_start   ,   //单个寄存器配置触发信号
    output  wire    [31:0]  cfg_data    ,   //ID,REG_ADDR,REG_VAL
    output  reg             cfg_done        //寄存器配置完成
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//

//parameter define
parameter   REG_NUM         =   7'd6   ;   //总共需要配置的寄存器个数
parameter   CNT_WAIT_MAX    =   10'd1023;   //寄存器配置等待计数最大值

//wire  define
wire    [31:0]  cfg_data_reg[REG_NUM-1:0]   ;   //寄存器配置数据暂存

//reg   define
reg     [9:0]   cnt_wait    ;   //寄存器配置等待计数器
reg     [6:0]   reg_num     ;   //配置寄存器个数

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//

//cnt_wait:寄存器配置等待计数器
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_wait    <=  15'd0;
    else    if(cnt_wait < CNT_WAIT_MAX)
        cnt_wait    <=  cnt_wait + 1'b1;

//reg_num:配置寄存器个数
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        reg_num <=  7'd0;
    else    if(cfg_end == 1'b1)
        reg_num <=  reg_num + 1'b1;

//cfg_start:单个寄存器配置触发信号
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cfg_start   <=  1'b0;
    else    if(cnt_wait == (CNT_WAIT_MAX - 1'b1))
        cfg_start   <=  1'b1;
    else    if((cfg_end == 1'b1) && (reg_num < REG_NUM))
        cfg_start   <=  1'b1;
    else
        cfg_start   <=  1'b0;

//cfg_done:寄存器配置完成
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cfg_done    <=  1'b0;
    else    if((reg_num == REG_NUM) && (cfg_end == 1'b1))
        cfg_done    <=  1'b1;

//cfg_data:ID,REG_ADDR,REG_VAL
assign  cfg_data = (cfg_done == 1'b1) ? 32'h0000 : cfg_data_reg[reg_num];

//----------------------------------------------------
//cfg_data_reg：寄存器配置数据暂存  ID   REG_ADDR REG_VAL
//assign  cfg_data_reg[00]  =       {8'h12,  8'h80};
assign  cfg_data_reg[0]  ={8'h72,16'h08,8'h35};
assign  cfg_data_reg[1]  ={8'h7a,16'h2f,8'h00};
assign  cfg_data_reg[2]  ={8'h60,16'h05,8'h10};
assign  cfg_data_reg[3]  ={8'h60,16'h08,8'h05};
assign  cfg_data_reg[4]  ={8'h60,16'h09,8'h01};
assign  cfg_data_reg[5]  ={8'h60,16'h05,8'h04};


//-------------------------------------------------------

endmodule
