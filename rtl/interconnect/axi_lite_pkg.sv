package axi_lite_pkg;
    // Five independent AXI4-Lite channels, grouped only for port readability.
    typedef struct packed {
        logic [31:0] awaddr;
        logic [2:0] awprot;
        logic awvalid;
        logic [31:0] wdata;
        logic [3:0] wstrb;
        logic wvalid;
        logic bready;
        logic [31:0] araddr;
        logic [2:0] arprot;
        logic arvalid;
        logic rready;
    } axil_req_t;
    typedef struct packed {
        logic awready;
        logic wready;
        logic [1:0] bresp;
        logic bvalid;
        logic arready;
        logic [31:0] rdata;
        logic [1:0] rresp;
        logic rvalid;
    } axil_rsp_t;
endpackage
