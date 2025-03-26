#ifndef FAIRY_STOCKFISH_API_H
#define FAIRY_STOCKFISH_API_H

#ifdef __cplusplus
extern "C" {
#endif

// Initialize the engine with optional variant name
void fs_init(const char* variantName);

// Send a UCI command directly to the engine
void fs_command(const char* cmd);

// Set UCI options
void fs_set_option(const char* name, const char* value);

// Set position from FEN string
void fs_set_position(const char* fen);

// Set position after moves
void fs_set_position_after_moves(const char* fen, const char* moves);

// Get best move with given time in milliseconds
const char* fs_get_best_move(int time_ms);

// Clean up resources
void fs_quit(void);

// Register a callback for best move (optional)
void fs_register_best_move_callback(void (*callback)(const char* move));

#ifdef __cplusplus
}
#endif

#endif /* FAIRY_STOCKFISH_API_H */
