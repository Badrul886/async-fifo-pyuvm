// ============================================================================
// MODULE 1: The 2-Stage Synchronizer
// ============================================================================
module sync2 #(parameter ADDR_WIDTH = 4) (
    input  logic clk,
    input  logic rst_n,
    input  logic [ADDR_WIDTH:0] d,  // Gray code input from other domain
    output logic [ADDR_WIDTH:0] q   // Synchronized output
);
    logic [ADDR_WIDTH:0] q1; // The intermediate stage

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q1 <= 0;
            q  <= 0;
        end else begin
            q1 <= d;   // Stage 1 catches the signal
            q  <= q1;  // Stage 2 stabilizes it
        end
    end
endmodule

// ============================================================================
// MODULE 2: The Dual-Port Memory Array
// ============================================================================
module fifomem #(parameter DEPTH = 8, parameter DATA_WIDTH = 8, parameter ADDR_WIDTH = 3) (
    input  logic wclk,
    input  logic w_en,
    input  logic [ADDR_WIDTH-1:0] waddr,
    input  logic [ADDR_WIDTH-1:0] raddr,
    input  logic [DATA_WIDTH-1:0] wdata,
    output logic [DATA_WIDTH-1:0] rdata
);
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Write uses the Write Clock
    always_ff @(posedge wclk) begin
        if (w_en) mem[waddr] <= wdata;
    end

    // Read is continuous (combinational out) for simplicity, or can be clocked.
    assign rdata = mem[raddr];
endmodule

// ============================================================================
// MODULE 3: Read Pointer & Empty Logic (Read Clock Domain)
// ============================================================================
module rptr_empty #(parameter ADDR_WIDTH = 3) (
    input  logic rclk,
    input  logic rst_n,
    input  logic r_en,
    input  logic [ADDR_WIDTH:0] rq2_wptr, // Synchronized Write Pointer
    output logic empty,
    output logic [ADDR_WIDTH-1:0] raddr,  // Binary address for memory
    output logic [ADDR_WIDTH:0] rptr_g    // Gray code pointer to send to write domain
);
    logic [ADDR_WIDTH:0] rbin, rbin_next, rgray_next;
    logic empty_val;

    // Advance pointer only if reading and not empty
    assign rbin_next  = rbin + (r_en & ~empty);
    // BINARY TO GRAY CODE CONVERSION MATH: (binary shifted right by 1) XOR (binary)
    assign rgray_next = (rbin_next >> 1) ^ rbin_next;
    
    // Address for memory is just the lower bits of the binary pointer
    assign raddr = rbin[ADDR_WIDTH-1:0];

    // FIFO is empty when Read Gray == Write Gray exactly
    assign empty_val = (rgray_next == rq2_wptr);

    always_ff @(posedge rclk or negedge rst_n) begin
        if (!rst_n) begin
            rbin   <= 0;
            rptr_g <= 0;
            empty  <= 1'b1;
        end else begin
            rbin   <= rbin_next;
            rptr_g <= rgray_next;
            empty  <= empty_val;
        end
    end
endmodule

// ============================================================================
// MODULE 4: Write Pointer & Full Logic (Write Clock Domain)
// ============================================================================
module wptr_full #(parameter ADDR_WIDTH = 3) (
    input  logic wclk,
    input  logic rst_n,
    input  logic w_en,
    input  logic [ADDR_WIDTH:0] wq2_rptr, // Synchronized Read Pointer
    output logic full,
    output logic [ADDR_WIDTH-1:0] waddr,  // Binary address for memory
    output logic [ADDR_WIDTH:0] wptr_g    // Gray code pointer to send to read domain
);
    logic [ADDR_WIDTH:0] wbin, wbin_next, wgray_next;
    logic full_val;

    // Advance pointer only if writing and not full
    assign wbin_next  = wbin + (w_en & ~full);
    // BINARY TO GRAY CODE CONVERSION
    assign wgray_next = (wbin_next >> 1) ^ wbin_next;
    
    assign waddr = wbin[ADDR_WIDTH-1:0];

    // FIFO is full when Write Gray == Read Gray, EXCEPT the top two bits are inverted!
    // This mathematical trick detects that the write pointer has exactly lapped the read pointer.
    assign full_val = (wgray_next == {~wq2_rptr[ADDR_WIDTH:ADDR_WIDTH-1], wq2_rptr[ADDR_WIDTH-2:0]});

    always_ff @(posedge wclk or negedge rst_n) begin
        if (!rst_n) begin
            wbin   <= 0;
            wptr_g <= 0;
            full   <= 1'b0;
        end else begin
            wbin   <= wbin_next;
            wptr_g <= wgray_next;
            full   <= full_val;
        end
    end
endmodule

// ============================================================================
// MODULE 5: TOP-LEVEL ASYNCHRONOUS FIFO (Wiring it all together)
// ============================================================================
module async_fifo #(parameter DEPTH = 8, parameter DATA_WIDTH = 8, parameter ADDR_WIDTH = 3) (
    // Write Domain
    input  logic wclk,
    input  logic wrst_n,
    input  logic write_en,
    input  logic [DATA_WIDTH-1:0] write_data,
    output logic full,
    
    // Read Domain
    input  logic rclk,
    input  logic rrst_n,
    input  logic read_en,
    output logic [DATA_WIDTH-1:0] read_data,
    output logic empty
);

    // Internal routing wires
    logic [ADDR_WIDTH:0] wptr_g, rptr_g;
    logic [ADDR_WIDTH:0] wq2_rptr, rq2_wptr;
    logic [ADDR_WIDTH-1:0] waddr, raddr;

    // 1. Instantiate Write Synchronizer (Passes Read Pointer to Write Domain)
    sync2 #(ADDR_WIDTH) sync_w2r (
        .clk(wclk), .rst_n(wrst_n), .d(rptr_g), .q(wq2_rptr)
    );

    // 2. Instantiate Read Synchronizer (Passes Write Pointer to Read Domain)
    sync2 #(ADDR_WIDTH) sync_r2w (
        .clk(rclk), .rst_n(rrst_n), .d(wptr_g), .q(rq2_wptr)
    );

    // 3. Instantiate Dual-Port Memory
    fifomem #(DEPTH, DATA_WIDTH, ADDR_WIDTH) fifomem_inst (
        .wclk(wclk), .w_en(write_en && !full), .waddr(waddr), .raddr(raddr),
        .wdata(write_data), .rdata(read_data)
    );

    // 4. Instantiate Read Pointer & Empty Logic
    rptr_empty #(ADDR_WIDTH) rptr_empty_inst (
        .rclk(rclk), .rst_n(rrst_n), .r_en(read_en), .rq2_wptr(rq2_wptr),
        .empty(empty), .raddr(raddr), .rptr_g(rptr_g)
    );

    // 5. Instantiate Write Pointer & Full Logic
    wptr_full #(ADDR_WIDTH) wptr_full_inst (
        .wclk(wclk), .rst_n(wrst_n), .w_en(write_en), .wq2_rptr(wq2_rptr),
        .full(full), .waddr(waddr), .wptr_g(wptr_g)
    );

endmodule
