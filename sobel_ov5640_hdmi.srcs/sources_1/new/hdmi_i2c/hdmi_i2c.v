`timescale 1ns / 1ps



module hdmi_i2c(
    input   wire            sys_clk         ,   //ϵͳʱ��
    input   wire            sys_rst_n       ,   //��λ�ź�

    output  wire            cfg_done        ,   //�Ĵ����������
    output  wire            sccb_scl        ,   //SCL
    inout   wire            sccb_sda           //SDA


    );
    
    
//parameter define
parameter    BIT_CTRL   =  1'b0         ; // �ֵ�ַλ���Ʋ���(16b/8b)
parameter    CLK_FREQ   = 26'd25_000_000; // i2c_driģ�������ʱ��Ƶ��(CLK_FREQ)
parameter    I2C_FREQ   = 18'd250_000   ; // I2C��SCLʱ��Ƶ��

//wire  define
wire            cfg_end     ;
wire            cfg_start   ;
wire    [31:0]  cfg_data    ;
wire            cfg_clk     ;
hdmi_i2c_ctrl
#(
    .SYS_CLK_FREQ   (CLK_FREQ   ), //i2c_ctrlģ��ϵͳʱ��Ƶ��
    .SCL_FREQ       (I2C_FREQ   )  //i2c��SCLʱ��Ƶ��
)
hdmi_i2c_ctrl_inst
(
    .sys_clk     (sys_clk       ),   //����ϵͳʱ��,50MHz
    .sys_rst_n   (sys_rst_n     ),   //���븴λ�ź�,�͵�ƽ��Ч
    .wr_en       (1'b1          ),   //����дʹ���ź�
    .rd_en       (              ),   //�����ʹ���ź�
    .i2c_start   (cfg_start     ),   //����i2c�����ź�
    .addr_num    (BIT_CTRL      ),   //����i2c�ֽڵ�ַ�ֽ���
    .device_addr (cfg_data[31:24]),
    .byte_addr   (cfg_data[23:8]),   //����i2c�ֽڵ�ַ
    .wr_data     (cfg_data[7:0] ),   //����i2c�豸����

    .rd_data     (              ),   //���i2c�豸��ȡ����
    .i2c_end     (cfg_end       ),   //i2cһ�ζ�/д�������
    .i2c_clk     (cfg_clk       ),   //i2c����ʱ��
    .i2c_scl     (sccb_scl      ),   //�����i2c�豸�Ĵ���ʱ���ź�scl
    .i2c_sda     (sccb_sda      )    //�����i2c�豸�Ĵ��������ź�sda
);

//------------- hdmi_cfg_inst -------------
hdmi_cfg  hdmi_cfg_inst(

    .sys_clk        (cfg_clk    ),   //ϵͳʱ��,��iicģ�鴫��
    .sys_rst_n      (sys_rst_n  ),   //ϵͳ��λ,����Ч
    .cfg_end        (cfg_end    ),   //�����Ĵ����������

    .cfg_start      (cfg_start  ),   //�����Ĵ������ô����ź�
    .cfg_data       (cfg_data   ),   //ID,REG_ADDR,REG_VAL
    .cfg_done       (cfg_done   )    //�Ĵ����������
);
endmodule
