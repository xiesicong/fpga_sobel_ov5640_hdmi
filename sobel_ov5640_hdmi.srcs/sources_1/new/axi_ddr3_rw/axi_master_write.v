`timescale  1ns/1ns

module axi_master_write
(
  input           ARESETN    , //axi��λ
  input           ACLK       , //axi��ʱ��
//axi4дͨ����ַͨ��
  output [3:0]  M_AXI_AWID   , //д��ַID��������־һ��д�ź�
  output [31:0] M_AXI_AWADDR , //д��ַ������һ��дͻ�������д��ַ
  output [7:0]  M_AXI_AWLEN  , //ͻ�����ȣ�����ͻ������Ĵ���  
  output [2:0]  M_AXI_AWSIZE , //ͻ����С������ÿ��ͻ��������ֽ���  
  output [1:0]  M_AXI_AWBURST, //ͻ������  
  output        M_AXI_AWLOCK , //�������źţ����ṩ������ԭ����  
  output [3:0]  M_AXI_AWCACHE, //�ڴ����ͣ�����һ�δ���������ͨ��ϵͳ��  
  output [2:0]  M_AXI_AWPROT , //�������ͣ�����һ�δ������Ȩ������ȫ�ȼ�  
  output [3:0]  M_AXI_AWQOS  , //��������QoS     
  output        M_AXI_AWVALID, //��Ч�źţ�������ͨ���ĵ�ַ�����ź���Ч
  input         M_AXI_AWREADY, //�������ӡ����Խ��յ�ַ�Ͷ�Ӧ�Ŀ����ź�
//axi4дͨ������ͨ��
  output [63:0] M_AXI_WDATA  , //д����
  output [7:0]  M_AXI_WSTRB  , //д������Ч���ֽ���
  output        M_AXI_WLAST  , //�����˴δ��������һ��ͻ������
  output        M_AXI_WVALID , //д��Ч�������˴�д��Ч
  input         M_AXI_WREADY , //�����ӻ����Խ���д����
//axi4дͨ��Ӧ��ͨ��
  input [3:0]   M_AXI_BID    , //д��ӦID TAG
  input [1:0]   M_AXI_BRESP  , //д��Ӧ������д�����״̬
  input         M_AXI_BVALID , //д��Ӧ��Ч
  output        M_AXI_BREADY , //���������ܹ�����д��Ӧ
  //�û����ź�
  input         WR_START     , //дͻ�������ź�
  input [31:0]  WR_ADRS      , //��ַ  
  input [9:0]  WR_LEN        , //����
  output        WR_READY     , //д����
  output        WR_FIFO_RE   , //���ӵ�дfifo�Ķ�ʹ��
  input [63:0]  WR_FIFO_DATA , //���ӵ�fifo�Ķ�����
  output        WR_DONE        //���һ��ͻ��
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//

localparam S_WR_IDLE  = 3'd0;//д����
localparam S_WA_WAIT  = 3'd1;//д��ַ�ȴ�
localparam S_WA_START = 3'd2;//д��ַ
localparam S_WD_WAIT  = 3'd3;//д���ݵȴ�
localparam S_WD_PROC  = 3'd4;//д����ѭ��
localparam S_WR_WAIT  = 3'd5;//����дӦ��
localparam S_WR_DONE  = 3'd6;//д����
//reg define  
reg [2:0]   wr_state   ; //״̬�Ĵ���
reg [31:0]  reg_wr_adrs; //��ַ�Ĵ���
reg         reg_awvalid; //��ַ��Ч�����ź�
reg         reg_wvalid ; //������Ч�����ź�
reg         reg_w_last ; //�������һ������
reg [7:0]   reg_w_len  ; //ͻ���������256��ʵ��128���
reg [7:0]   reg_w_stb  ;

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//

//д����źŵ�д״̬���
assign WR_DONE = (wr_state == S_WR_DONE);
//дfifo�Ķ�ʹ��Ϊaxi�������ֳɹ�
assign WR_FIFO_RE         = ((reg_wvalid & M_AXI_WREADY ));
//ֻ��һ������������������
assign M_AXI_AWID         = 4'b1111;
//�ѵ�ַ��������
assign M_AXI_AWADDR[31:0] = reg_wr_adrs[31:0];
//һ��ͻ������1����
assign M_AXI_AWLEN[7:0]   = WR_LEN-'d1;
//��ʾAXI����ÿ�����ݿ����8�ֽڣ�64λ
assign M_AXI_AWSIZE[2:0]  = 3'b011;
//01�����ַ������10����ݼ�
assign M_AXI_AWBURST[1:0] = 2'b01; 
assign M_AXI_AWLOCK       = 1'b0;
assign M_AXI_AWCACHE[3:0] = 4'b0010;
assign M_AXI_AWPROT[2:0]  = 3'b000;
assign M_AXI_AWQOS[3:0]   = 4'b0000;
//��ַ�����ź�AWVALID
assign M_AXI_AWVALID      = reg_awvalid;
//fifo���ݸ�������
assign M_AXI_WDATA[63:0]  = WR_FIFO_DATA[63:0];
assign M_AXI_WSTRB[7:0]   = 8'hFF;
//д�����һ������
assign M_AXI_WLAST        =(reg_w_len[7:0] == 8'd0)?'b1:'b0;
//���������ź�WVALID
assign M_AXI_WVALID       = reg_wvalid;
//����ź��Ǹ���AXI���յ����Ӧ��
assign M_AXI_BREADY       = M_AXI_BVALID;
//axi״̬�������ź�
assign WR_READY           = (wr_state == S_WR_IDLE)?1'b1:1'b0;

//axiд����״̬��
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
        S_WR_IDLE: begin //д����
          if(WR_START) begin //����д����
            wr_state          <= S_WA_WAIT;
            reg_wr_adrs[31:0] <= WR_ADRS[31:0];
          end
          reg_awvalid         <= 1'b0;
          reg_wvalid          <= 1'b0;
          reg_w_len[7:0]      <= 8'd0;
        end
        S_WA_WAIT: begin//д��ַ�ȴ�
          wr_state        <= S_WA_START;//�ȴ�һ������
        end
        S_WA_START: begin
          wr_state        <= S_WD_WAIT;//д���ݵȴ�
          reg_awvalid     <= 1'b1; //���ߵ�ַ��Ч�ź� 
          reg_wvalid      <= 1'b1;//����������Ч�ź�
        end
        S_WD_WAIT: begin
          if(M_AXI_AWREADY) begin//�ȴ�д��ַ����
            wr_state        <= S_WD_PROC;
            reg_w_len<=WR_LEN-'d1;//127����128�����ȣ�0����1������
            reg_awvalid     <= 1'b0;
          end
        end
        S_WD_PROC: begin//�ȴ�AXIд���ݾ����ź�
          if(M_AXI_WREADY) begin//�����˾Ϳ������fifoʹ���źſ�ʼ��
            
            if(reg_w_len[7:0] == 8'd0) begin//�������д����
              wr_state        <= S_WR_WAIT;
              reg_wvalid      <= 1'b0;//���źŸ���AXI����������д������Ч
              reg_w_last<='b1;
              //�������һ�����ݣ����������־�źŸ���AXI�����������һ��
              //��������ߴ��䲻��ɹ�
            end           
            else begin
              reg_w_len[7:0]  <= reg_w_len[7:0] -8'd1;
            end
          end
        end
        S_WR_WAIT: begin//�ȴ�д��AXIӦ���ź�
          reg_w_last<='b0;
          //M_AXI_BVALID���߱�ʾд�ɹ���Ȼ��״̬�����һ��ͻ������
          if(M_AXI_BVALID) begin
              wr_state          <= S_WR_DONE;
          end
        end
        S_WR_DONE: begin //д���           
            wr_state <= S_WR_IDLE;
          end
        
        default: begin
          wr_state <= S_WR_IDLE;
        end
      endcase
      end
  end

endmodule

