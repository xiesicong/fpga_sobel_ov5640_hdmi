`timescale 1ns / 1ps



module hdmi_i2c(
    input   wire            sys_clk         ,   //系统时钟
    input   wire            sys_rst_n       ,   //复位信号

    output  wire            cfg_done        ,   //寄存器配置完成
    output  wire            sccb_scl        ,   //SCL
    inout   wire            sccb_sda           //SDA


    );
    
    
//parameter define
parameter    BIT_CTRL   =  1'b0         ; // 字地址位控制参数(16b/8b)
parameter    CLK_FREQ   = 26'd25_000_000; // i2c_dri模块的驱动时钟频率(CLK_FREQ)
parameter    I2C_FREQ   = 18'd250_000   ; // I2C的SCL时钟频率

//wire  define
wire            cfg_end     ;
wire            cfg_start   ;
wire    [31:0]  cfg_data    ;
wire            cfg_clk     ;
hdmi_i2c_ctrl
#(
    .SYS_CLK_FREQ   (CLK_FREQ   ), //i2c_ctrl模块系统时钟频率
    .SCL_FREQ       (I2C_FREQ   )  //i2c的SCL时钟频率
)
hdmi_i2c_ctrl_inst
(
    .sys_clk     (sys_clk       ),   //输入系统时钟,50MHz
    .sys_rst_n   (sys_rst_n     ),   //输入复位信号,低电平有效
    .wr_en       (1'b1          ),   //输入写使能信号
    .rd_en       (              ),   //输入读使能信号
    .i2c_start   (cfg_start     ),   //输入i2c触发信号
    .addr_num    (BIT_CTRL      ),   //输入i2c字节地址字节数
    .device_addr (cfg_data[31:24]),
    .byte_addr   (cfg_data[23:8]),   //输入i2c字节地址
    .wr_data     (cfg_data[7:0] ),   //输入i2c设备数据

    .rd_data     (              ),   //输出i2c设备读取数据
    .i2c_end     (cfg_end       ),   //i2c一次读/写操作完成
    .i2c_clk     (cfg_clk       ),   //i2c驱动时钟
    .i2c_scl     (sccb_scl      ),   //输出至i2c设备的串行时钟信号scl
    .i2c_sda     (sccb_sda      )    //输出至i2c设备的串行数据信号sda
);

//------------- hdmi_cfg_inst -------------
hdmi_cfg  hdmi_cfg_inst(

    .sys_clk        (cfg_clk    ),   //系统时钟,由iic模块传入
    .sys_rst_n      (sys_rst_n  ),   //系统复位,低有效
    .cfg_end        (cfg_end    ),   //单个寄存器配置完成

    .cfg_start      (cfg_start  ),   //单个寄存器配置触发信号
    .cfg_data       (cfg_data   ),   //ID,REG_ADDR,REG_VAL
    .cfg_done       (cfg_done   )    //寄存器配置完成
);
endmodule
