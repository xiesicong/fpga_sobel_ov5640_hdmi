
module image_sobel_process
#(
    parameter   H_PIXEL = 10'd200,
    parameter   V_PIXEL = 10'd200
)
(
    input wire  image_valid,
    input wire  [15:0]ram_data,
    input wire  vsync,
    output wire sobel_valid,
    output wire [7:0]sobel_data,
    input wire  vga_sync_clk,
    input wire  rstn
);
        
parameter VEDIO_X_LENTH=H_PIXEL;
parameter VEDIO_Y_LENTH=V_PIXEL;
reg [23:0]pix_cnt_reg;        
wire [7:0]rgb_red;
wire [7:0]rgb_green;
wire [7:0]rgb_blue;

wire [7:0]pix_data_line1;
wire [7:0]pix_data_line2;
wire [7:0]pix_data_line3;
wire fifo_rd_en1;
wire fifo_rd_en2;

wire fifo_wr_en1;
wire fifo_wr_en2;


wire [17:0]ycbcr_y_tmp;
wire [7:0]ycbcr_y;

wire[7:0]fifo1_data_read;
wire[7:0]fifo2_data_read;

assign sobel_valid=image_valid;
assign  pix_data_line1=fifo2_data_read;
assign  pix_data_line2=fifo1_data_read;
assign  pix_data_line3=ycbcr_y;


always@(posedge vga_sync_clk or negedge rstn)begin
    if(rstn=='b0)begin
        pix_cnt_reg<='b0;
    end
    else begin
        if(image_valid)pix_cnt_reg<=pix_cnt_reg+'d1;
        else if(vsync=='b0)pix_cnt_reg<='d0;
    end
end


assign fifo_rd_en1=image_valid&((pix_cnt_reg>=VEDIO_X_LENTH)?'b1:'b0);
assign fifo_rd_en2=image_valid&((pix_cnt_reg>=VEDIO_X_LENTH*2)?'b1:'b0);
assign fifo_wr_en1=image_valid;
assign fifo_wr_en2=image_valid&((pix_cnt_reg>=VEDIO_X_LENTH)?'b1:'b0);



assign rgb_red=  {ram_data[4:0],3'b000};
assign rgb_green={ram_data[10:5],2'b00};
assign rgb_blue= {ram_data[15:11],3'b000};

//几个转换系数，全部放大1024倍，大家从网上查到的转换公式，系数乘以1024就是下面的参数
parameter KYR=306;
parameter KYG=601;
parameter KYB=116;
parameter OFFSET_Y=0;
//这里只计算Y
assign ycbcr_y_tmp=KYR*rgb_red+KYG*rgb_green+KYB*rgb_blue+OFFSET_Y;
assign ycbcr_y=ycbcr_y_tmp[17:10];

reg[7:0]pix_reg11;
reg[7:0]pix_reg12;
reg[7:0]pix_reg13;

reg[7:0]pix_reg21;
reg[7:0]pix_reg22;
reg[7:0]pix_reg23;

reg[7:0]pix_reg31;
reg[7:0]pix_reg32;
reg[7:0]pix_reg33;

//assign sobel_data= (pix_cnt_reg>=VEDIO_X_LENTH*2) 255-(gx_tmp[6:0]+gy_tmp[6:0]);
assign sobel_data= (pix_cnt_reg>=VEDIO_X_LENTH*2) ? 255-(gx_tmp[6:0]+gy_tmp[6:0]) : 8'd0;

wire [12:0]gx_tmp;
wire [12:0]gy_tmp;

reg [12:0]gx_reg;
reg [12:0]gy_reg;


assign gx_tmp=gx_reg[12]?('d8192-gx_reg):gx_reg;//求绝对值
assign gy_tmp=gy_reg[12]?('d8192-gy_reg):gy_reg;//求绝对值

always@(posedge vga_sync_clk or negedge rstn)begin
    if(rstn=='b0)begin
        gx_reg<='d0;
        gy_reg<='d0;
        pix_reg11<='d0; pix_reg12<='d0; pix_reg13<='d0;
        pix_reg21<='d0; pix_reg22<='d0; pix_reg23<='d0;
        pix_reg31<='d0; pix_reg32<='d0; pix_reg33<='d0;    
    end
    else begin
        pix_reg13<=pix_reg12; pix_reg12<=pix_reg11;pix_reg11<=pix_data_line1;
        pix_reg23<=pix_reg22; pix_reg22<=pix_reg21;pix_reg21<=pix_data_line2;
        pix_reg33<=pix_reg32; pix_reg32<=pix_reg31;pix_reg31<=pix_data_line3;
        gx_reg<=(pix_reg33+(pix_reg23+pix_reg23)+pix_reg13)-(pix_reg11+(pix_reg21+pix_reg21)+pix_reg31);
        gy_reg<=(pix_reg11+(pix_reg12+pix_reg12)+pix_reg13)-(pix_reg31+(pix_reg32+pix_reg32)+pix_reg33);
    end
end

fifo_pic fifo_generator_0_inst1
(
    .clk(vga_sync_clk),
    .srst(~vsync),
    .din(pix_data_line3),
    .wr_en(fifo_wr_en1),
    .rd_en(fifo_rd_en1),
    .dout(fifo1_data_read),
    .full(),
    .empty()
);
fifo_pic fifo_generator_0_inst2
(
    .clk(vga_sync_clk),
    .srst(~vsync),
    .din(pix_data_line2),
    .wr_en(fifo_wr_en2),
    .rd_en(fifo_rd_en2),
    .dout(fifo2_data_read),
    .full(),
    .empty()
);                       
endmodule
