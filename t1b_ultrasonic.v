/*
Module HC_SR04 Ultrasonic Sensor

This module will detect objects present in front of the range, and give the distance in mm.

Input:  clk_50M - 50 MHz clock
        reset   - reset input signal (Use negative reset)
        echo_rx - receive echo from the sensor

Output: trig    - trigger sensor for the sensor
        op     -  output signal to indicate object is present.
        distance_out - distance in mm, if object is present.
*/

// module Declaration
module t1b_ultrasonic(
    input clk_50M, 
    input reset, 
    input echo_rx,
    output reg trig,
    output op,
    output wire [15:0] distance_out
);

initial begin
    trig = 0;
end

//---------------------------
// State Machine Definitions
//---------------------------
parameter IDLE        = 3'b000; 
parameter PRE_TRIGGER = 3'b001; 
parameter TRIGGER_ON  = 3'b010; 
parameter WAIT_ECHO   = 3'b011; 
parameter COUNT_ECHO_CALC_DIST  = 3'b100; 
parameter SET_OP_REG   = 3'b101; 
parameter GO_NEXT      = 3'b110; 
parameter WAIT_NEXT   = 3'b111; 

reg [2:0] state = IDLE;
reg [19:0] counter = 0;
reg [19:0] echo_counter = 0;

// Output holding registers with explicit initialization
reg op_reg = 1'b0;
reg [15:0] distance_reg = 16'd0;

// Connect internal registers to outputs
assign op = op_reg;
assign distance_out = distance_reg;

//---------------------------
// Timing constants (in 50 MHz cycles)
//---------------------------
localparam ONE_US     = 50;
localparam TEN_US     = 500;
localparam TWELVE_MS  = 600000;

//=============================================================
// Main FSM process
//=============================================================
always @(posedge clk_50M or negedge reset) begin
    if (!reset) begin
        state         <= IDLE;
        trig          <= 0;
        op_reg        <= 0;
        distance_reg  <= 0;
        counter       <= 0;
        echo_counter  <= 0;
    end
    else begin
        case (state)
        
        IDLE: begin
            trig <= 0;
            if (counter < ONE_US)
                counter <= counter + 1;
            else begin		
                counter <= 0;
                state <= PRE_TRIGGER;
            end
        end
        
        PRE_TRIGGER: begin
            trig    <= 1;
            counter <= 1;
            state   <= TRIGGER_ON;
        end
        
        TRIGGER_ON: begin   
            if (counter < TEN_US) begin 
                counter <= counter + 1;
                trig <= 1;
            end
            else begin 
                trig <= 0;
                counter <= 0;
                state <= WAIT_ECHO;
            end
        end
        
        WAIT_ECHO: begin
            counter <= counter + 1;
            if (echo_rx == 1) begin
                echo_counter <= 0;
                state <= COUNT_ECHO_CALC_DIST;
            end
        end

        COUNT_ECHO_CALC_DIST: begin
            counter <= counter + 1;
            if (echo_rx == 1) begin
                echo_counter <= echo_counter + 1;
            end
            else begin
                // Calculate distance
                distance_reg <= (echo_counter * 34) / 10000;
                state <= SET_OP_REG;
            end
        end

        SET_OP_REG: begin
            if (distance_reg < 70) begin
                op_reg <= 1;
            end
            else begin
                op_reg <= 0;
            end
            
            state <= GO_NEXT;
        end
        
        GO_NEXT: begin
            state <= WAIT_NEXT;
        end

        WAIT_NEXT: begin
            counter <= counter + 1;
            if (counter == TWELVE_MS - 1) begin
                counter <= 0;
                state <= IDLE;
            end
        end
        
        endcase
    end
end

endmodule