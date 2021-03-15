

module  ov5640_ddr_hdmi
(
    input   wire    sys_clk          , //系统时钟
    input   wire    sys_rst_n        ,//系统复位，低电平有效
//摄像头接口
    output  wire            cam_rst_n,  //摄像1与2头复位信号，低电平有效
    output  wire            cam_pwdn ,  //摄像1与2头时钟选择信号
    
    input   wire            cam1_pclk ,  //摄像1头数据像素时钟
    input   wire            cam1_vsync,  //摄像1头场同步信号
    input   wire            cam1_href ,  //摄像1头行同步信号
    input   wire    [7:0]   cam1_data ,  //摄像1头数据
    output  wire            sccb1_scl    ,  //摄像头1SCCB_SCL线
    inout   wire            sccb1_sda    ,  //摄像头1SCCB_SDA线
//HDMI
    output  wire            ddc_scl        ,
    inout   wire            ddc_sda        ,
    output  wire            hdmi_out_clk   ,
    output  wire            hdmi_out_rst_n ,
    output  wire            hdmi_out_hsync ,   //输出行同步信号
    output  wire            hdmi_out_vsync ,   //输出场同步信号
    output  wire    [23:0]  hdmi_out_rgb   ,   //输出像素信息
    output  wire            hdmi_out_de    ,


//DDR3接口
    inout [31:0]       ddr3_dq,
    inout [3:0]        ddr3_dqs_n,
    inout [3:0]        ddr3_dqs_p,
    output [14:0]      ddr3_addr,
    output [2:0]       ddr3_ba,
    output             ddr3_ras_n,
    output             ddr3_cas_n,
    output             ddr3_we_n,
    output             ddr3_reset_n,
    output [0:0]       ddr3_ck_p,
    output [0:0]       ddr3_ck_n,
    output [0:0]       ddr3_cke,
    output [0:0]       ddr3_cs_n,
    output [3:0]       ddr3_dm,
    output [0:0]       ddr3_odt

);
//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//
//parameter define
//水平方向像素个数,用于设置SDRAM缓存大小
parameter   H_PIXEL     =   24'd640 ;   
//垂直方向像素个数,用于设置SDRAM缓存大小
parameter   V_PIXEL     =   24'd480 ;


//wire  define
wire      locked;
wire      clk_25m     ; //100mhz时钟
wire      clk_320m     ; //625m
wire      rst_n        ; //复位信号(sys_rst_n & locked)
wire      wr_en        ; //sdram写使能
wire[15:0]wr_data      ; //sdram写数据
wire      rd_en        ; //sdram读使能
wire[15:0]rd_data      ; //sdram读数据
wire      c3_calib_done; //系统初始化完成(SDRAM初始化)
wire            sys_init_done; //系统初始化完成(SDRAM初始化+摄像头初始化)
wire            cam1_cfg_done     ;   //摄像头初始化完成
wire            cam1_wr_en        ;   //DDR写使能
wire   [15:0]   cam1_wr_data      ;   //DDR写数据
wire            cam1_rd_en        ;   //DDR读使能
wire   [15:0]   cam1_rd_data      ;   //DDR读数据
wire      ui_clk       ; //DDR3的读写时钟
wire      ui_rst       ; //ddr产生的复位信号
wire   [15:0] rgb;
wire   [13:0] vga_x;
wire            sobel_en;
wire    [7:0]   sobel_result;
//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//
assign  rst_n = sys_rst_n & c3_calib_done&(~ui_rst);
assign sys_init_done=c3_calib_done & cam1_cfg_done;

assign  hdmi_out_de=rd_en;
assign  hdmi_out_rst_n=sys_rst_n;
assign  hdmi_out_rgb   ={{rgb[15:11],3'b0},{rgb[10:5],2'b0},{rgb[4:0],3'b0}};
assign  hdmi_out_clk=clk_25m;


//ov5640_rst_n:摄像头复位,固定高电平
assign  cam_rst_n = 1'b1;
assign  cam_pwdn = 1'b0;


clk_wiz_0 clk_wiz_inst
(
    // Clock out ports  
    .clk_out1   (clk_25m    ),
    .clk_out2   (clk_320m   ),
    // Status and control signals               
    .reset      (~sys_rst_n ), 
    .locked     (locked     ),
    // Clock in ports
    .clk_in1    (sys_clk    )
);

ov5640_top  cam1(

    .sys_clk         (clk_25m       ),   //系统时钟
    .sys_rst_n       (rst_n         ),   //复位信号
    .sys_init_done   (sys_init_done ),   //系统初始化完成

    .ov5640_pclk     (cam1_pclk     ),   //摄像头像素时钟
    .ov5640_href     (cam1_href     ),   //摄像头行同步信号
    .ov5640_vsync    (cam1_vsync    ),   //摄像头场同步信号
    .ov5640_data     (cam1_data     ),   //摄像头图像数据

    .cfg_done        (cam1_cfg_done ),   //寄存器配置完成
    .sccb_scl        (sccb1_scl     ),   //SCL
    .sccb_sda        (sccb1_sda     ),   //SDA
    .ov5640_wr_en    (cam1_wr_en    ),   //图像数据有效使能信号
    .ov5640_data_out (cam1_wr_data  )    //图像数据
);

image_sobel_process 
#(
    .H_PIXEL (H_PIXEL),
    .V_PIXEL (V_PIXEL)
)
image_sobel_process_inst1
(
  .image_valid      (cam1_wr_en         ),
  .ram_data         (cam1_wr_data       ),
  .vsync            (~cam1_vsync        ),
  .sobel_valid      (sobel_en           ),
  .sobel_data       (sobel_result       ),
  .vga_sync_clk     (cam1_pclk          ),
  .rstn             (rst_n              )
);
assign wr_en = sobel_en;
assign wr_data={sobel_result[7:3],sobel_result[7:2],sobel_result[7:3]};

//------------- ddr_rw_inst -------------
//DDR读写控制部分
axi_ddr_top 
#(
.DDR_WR_LEN(64),//写突发长度 最大128个64bit
.DDR_RD_LEN(64)//读突发长度 最大128个64bit
)

ddr_rw_inst(
  .ddr3_clk     (clk_320m       ),
  .sys_rst_n    (sys_rst_n&locked),
  .pingpang     (0              ),
   //写用户接口
  .user_wr_clk  (cam1_pclk      ), //写时钟
  .data_wren    (wr_en          ), //写使能，高电平有效
  .data_wr      (wr_data        ), //写数据16位wr_data
  .wr_b_addr    (30'd0          ), //写起始地址
  .wr_e_addr    (H_PIXEL*V_PIXEL*2  ), //写结束地址,8位一字节对应一个地址，16位x2
  .wr_rst       (1'b0           ), //写地址复位 wr_rst
  //读用户接口   
  .user_rd_clk  (clk_25m    ), //读时钟
  .data_rden    (rd_en          ), //读使能，高电平有效
  .data_rd      (rd_data        ), //读数据16位
  .rd_b_addr    (30'd0          ), //读起始地址
  .rd_e_addr    (H_PIXEL*V_PIXEL*2  ), //写结束地址,8位一字节对应一个地址,16位x2
  .rd_rst       (1'b0           ), //读地址复位 rd_rst
  .read_enable  (1'b1           ),
   
  .ui_rst       (c3_rst0        ), //ddr产生的复位信号
  .ui_clk       (c3_clk0        ), //ddr操作时钟125m
  .calib_done   (c3_calib_done  ), //代表ddr初始化完成
  
  //物理接口
  .ddr3_dq      (ddr3_dq        ),
  .ddr3_dqs_n   (ddr3_dqs_n     ),
  .ddr3_dqs_p   (ddr3_dqs_p     ),
  .ddr3_addr    (ddr3_addr      ),
  .ddr3_ba      (ddr3_ba        ),
  .ddr3_ras_n   (ddr3_ras_n     ),
  .ddr3_cas_n   (ddr3_cas_n     ),
  .ddr3_we_n    (ddr3_we_n      ),
  .ddr3_reset_n (ddr3_reset_n   ),
  .ddr3_ck_p    (ddr3_ck_p      ),
  .ddr3_ck_n    (ddr3_ck_n      ),
  .ddr3_cke     (ddr3_cke       ),
  .ddr3_cs_n    (ddr3_cs_n      ),
  .ddr3_dm      (ddr3_dm        ),
  .ddr3_odt     (ddr3_odt       )
);


hdmi_i2c hdmi_i2c_inst(
    .sys_clk   (clk_25m     )   ,   //系统时钟
    .sys_rst_n (sys_rst_n   )   ,   //复位信号
    .cfg_done  (            )   ,   //寄存器配置完成
    .sccb_scl  (ddc_scl     )   ,   //SCL
    .sccb_sda  (ddc_sda     )       //SDA
    );

vga_ctrl  vga_ctrl_inst
(
    .vga_clk    (clk_25m        ),  //输入工作时钟,频率25MHz,1bit
    .sys_rst_n  (rst_n          ),  //输入复位信号,低电平有效,1bit
    .pix_data   (rd_data        ),  //输入像素点色彩信息,16bit

    .pix_x      (vga_x          ),  //输出VGA有效显示区域像素点X轴坐标,10bit
    .pix_y      (               ),  //输出VGA有效显示区域像素点Y轴坐标,10bit
    .hsync      (hdmi_out_hsync ),  //输出行同步信号,1bit
    .vsync      (hdmi_out_vsync ),  //输出场同步信号,1bit
    .rgb_valid  (rd_en          ),
    .rgb        (rgb            )   //输出像素点色彩信息,16bit
); 
endmodule
