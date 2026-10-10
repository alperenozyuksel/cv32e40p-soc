`timescale 1ns/1ps
module tb_soc_axi;
    logic clk=0,rst=0,fetch=0;
    always #5 clk=~clk;
    wire ir,ig,iv,dr;
    wire[31:0] ia,idata;
    wire[15:0] pins;
    wire error_flag;
    int grants=0,responses=0,checks=0;
    soc_top #(.INIT_FILE("axi_program.hex")) dut(
        .clk_i(clk),.rst_ni(rst),.fetch_enable_i(fetch),
        .instr_req(ir),.instr_addr(ia),.instr_gnt(ig),.instr_rvalid(iv),.instr_rdata(idata),
        .data_req(dr),.gpio_in_i(16'h5aa5),.gpio_out_o(pins),.bus_error_o(error_flag));
    axi_lite_checker checker_cpu(clk,rst,dut.cpu_axi_req,dut.cpu_axi_rsp);
    for(genvar i=0;i<3;i++) begin: monitors
        axi_lite_checker checker_target(clk,rst,dut.peripheral_axi_req[i],dut.peripheral_axi_rsp[i]);
    end
    always @(posedge clk) begin
        if(!rst) begin grants=0; responses=0; end
        else begin
            if(dr && dut.data_gnt) grants++;
            if(dut.data_rvalid) begin
                responses++;
                if(responses>grants) $fatal(1,"unsolicited OBI response");
            end
        end
    end
    initial begin
        for(int boot=0;boot<2;boot++) begin
            @(negedge clk); rst=0; fetch=0;
            repeat(5) @(negedge clk);
            if(error_flag !== 0 || pins !== 0) $fatal(1,"SoC reset");
            rst=1;
            repeat(3) begin @(negedge clk); if(ir) $fatal(1,"fetch before enable"); end
            fetch=1;
            for(int n=0;n<10000;n++) begin
                @(negedge clk);
                if(dut.u_cpu.core_i.id_stage_i.register_file_i.mem[20]===32'hffffffff)
                    $fatal(1,"CPU software comparison failed at pc=%h",dut.u_cpu.core_i.pc_id);
                if(dut.u_cpu.core_i.pc_id===32'h1138) break;
                if(n==9999) $fatal(1,"CPU program timeout pc=%h",dut.u_cpu.core_i.pc_id);
            end
            repeat(20) @(negedge clk);
            if(dut.u_dmem.mem[64] !== 1) $fatal(1,"RAM success signature missing");
            if(pins !== 16'haa44) $fatal(1,"GPIO software output");
            if(error_flag !== 1) $fatal(1,"DECERR sticky flag absent");
            if(grants !== responses || grants<20) $fatal(1,"OBI counts %0d/%0d",grants,responses);
            checks++;
            $display("BOOT %0d AXI PASS grants=%0d responses=%0d",boot,grants,responses);
        end
        $display("PASS tb_soc_axi boots=%0d",checks); $finish;
    end
    initial begin #2000000; $fatal(1,"SoC timeout"); end
endmodule
