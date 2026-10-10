`timescale 1ns/1ps
module axi_lite_checker (
    input logic clk_i, rst_ni,
    input axi_lite_pkg::axil_req_t req,
    input axi_lite_pkg::axil_rsp_t rsp
);
    axi_lite_pkg::axil_req_t prev_req;
    axi_lite_pkg::axil_rsp_t prev_rsp;
    bit active;
    integer aw_count=0,w_count=0,b_count=0,ar_count=0,r_count=0;
    always @(posedge clk_i) begin
        if (!rst_ni) begin
            active=0; aw_count=0; w_count=0; b_count=0; ar_count=0; r_count=0;
        end else begin
            if ($isunknown({req.awvalid,req.wvalid,req.arvalid,req.bready,req.rready,
                            rsp.awready,rsp.wready,rsp.arready,rsp.bvalid,rsp.rvalid}))
                $fatal(1,"%m unknown AXI handshake");
            if(active) begin
                if(prev_req.awvalid && !prev_rsp.awready)
                    if(!req.awvalid || {req.awaddr,req.awprot} !== {prev_req.awaddr,prev_req.awprot})
                        $fatal(1,"%m AW unstable under stall");
                if(prev_req.wvalid && !prev_rsp.wready)
                    if(!req.wvalid || {req.wdata,req.wstrb} !== {prev_req.wdata,prev_req.wstrb})
                        $fatal(1,"%m W unstable under stall");
                if(prev_req.arvalid && !prev_rsp.arready)
                    if(!req.arvalid || {req.araddr,req.arprot} !== {prev_req.araddr,prev_req.arprot})
                        $fatal(1,"%m AR unstable under stall");
                if(prev_rsp.bvalid && !prev_req.bready)
                    if(!rsp.bvalid || rsp.bresp !== prev_rsp.bresp)
                        $fatal(1,"%m B unstable under stall");
                if(prev_rsp.rvalid && !prev_req.rready)
                    if(!rsp.rvalid || {rsp.rdata,rsp.rresp} !== {prev_rsp.rdata,prev_rsp.rresp})
                        $fatal(1,"%m R unstable under stall");
            end
            // Responses may only follow previously accepted address/data.
            if(rsp.bvalid && (b_count>=aw_count || b_count>=w_count))
                $fatal(1,"%m B response without accepted AW and W");
            if(rsp.rvalid && r_count>=ar_count)
                $fatal(1,"%m R response without accepted AR");
            if(req.awvalid && rsp.awready) aw_count++;
            if(req.wvalid && rsp.wready) w_count++;
            if(req.bready && rsp.bvalid) b_count++;
            if(req.arvalid && rsp.arready) ar_count++;
            if(req.rready && rsp.rvalid) r_count++;
            prev_req=req; prev_rsp=rsp; active=1;
        end
    end
endmodule
