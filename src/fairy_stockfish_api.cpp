#include "fairy_stockfish_api.h"
#include <string>
#include <sstream>
#include <mutex>
#include <thread>
#include <condition_variable>
#include <atomic>
#include <queue>
#include <cstring> // For strncpy

#include "position.h"
#include "uci.h"
#include "thread.h"

using namespace Stockfish;

namespace
{
    std::mutex apiMutex;
    std::condition_variable apiCV;
    std::atomic<bool> initialized(false);
    std::string bestMove;
    std::atomic<bool> bestMoveReady(false);
    std::thread *commandThread = nullptr;
    std::queue<std::string> commandQueue;
    std::mutex queueMutex;
    std::condition_variable queueCV;
    std::atomic<bool> quit(false);
    char moveBuffer[16];

    // Process UCI commands through a string stream
    void process_uci_command(const std::string &cmd)
    {
        std::istringstream is(cmd);
        std::string token;
        is >> std::skipws >> token;

        Position pos;
        StateInfo st;

        // No try-catch, just call the function directly
        if (Options.count("UCI_Variant") > 0)
        {
            pos.set(variants.find(Options["UCI_Variant"])->second,
                    variants.find(Options["UCI_Variant"])->second->startFen,
                    false, &st, Threads.main());
        }
        else
        {
            // If variant isn't set, use standard chess
            pos.set(variants.find("chess")->second,
                    variants.find("chess")->second->startFen,
                    false, &st, Threads.main());
        }

        if (token == "position")
        {
            // Handle position command
            std::string fen;
            is >> token;

            if (token == "startpos")
            {
                fen = variants.find(Options["UCI_Variant"])->second->startFen;
                is >> token; // Consume "moves" token if any
            }
            else if (token == "fen")
            {
                while (is >> token && token != "moves")
                    fen += token + " ";
            }

            StateListPtr states(new std::deque<StateInfo>(1));
            // No try-catch, just call the function directly
            pos.set(variants.find(Options["UCI_Variant"])->second, fen, false, &states->back(), Threads.main());

            // Parse move list (if any)
            if (token == "moves")
            {
                Move m;
                while (is >> token && (m = UCI::to_move(pos, token)) != MOVE_NONE)
                {
                    states->emplace_back();
                    pos.do_move(m, states->back());
                }
            }
        }
        else if (token == "go")
        {
            // Handle go command
            Search::LimitsType limits;
            limits.startTime = now();

            std::string token;
            while (is >> token)
            {
                if (token == "movetime")
                {
                    int time;
                    is >> time;
                    limits.movetime = time;
                    break;
                }
            }

            // No try-catch, just perform the operations directly
            // Start search
            StateListPtr states(new std::deque<StateInfo>(1));
            Threads.start_thinking(pos, states, limits, false);

            // Wait for search to complete
            Threads.main()->wait_for_search_finished();

            // Get best move
            if (!Threads.main()->rootMoves.empty())
            {
                std::lock_guard<std::mutex> lock(apiMutex);
                Move m = Threads.main()->rootMoves[0].pv[0];
                if (m != MOVE_NONE)
                {
                    bestMove = UCI::move(pos, m);
                    bestMoveReady = true;
                    apiCV.notify_all();
                }
                else
                {
                    // Provide a default move if none found
                    bestMove = "e2e4"; // Default fallback move
                    bestMoveReady = true;
                    apiCV.notify_all();
                }
            }
            else
            {
                // Provide a default move if no root moves
                std::lock_guard<std::mutex> lock(apiMutex);
                bestMove = "e2e4"; // Default fallback move
                bestMoveReady = true;
                apiCV.notify_all();
            }
        }
        else if (token == "setoption")
        {
            std::string name, value;

            is >> token; // Consume "name" token

            // Read option name (can contain spaces)
            while (is >> token && token != "value")
                name += (name.empty() ? "" : " ") + token;

            // Read option value (can contain spaces)
            while (is >> token)
                value += (value.empty() ? "" : " ") + token;

            if (Options.count(name))
                Options[name] = value;
        }
        else if (token == "ucinewgame")
        {
            Search::clear();
        }
        else if (token == "isready")
        {
            // Just notify that we're ready
            std::lock_guard<std::mutex> lock(apiMutex);
            apiCV.notify_all();
        }
    }

    // Command processing thread
    void command_thread_func()
    {
        while (!quit.load())
        {
            std::string cmd;
            {
                std::unique_lock<std::mutex> lock(queueMutex);
                queueCV.wait(lock, []
                             { return !commandQueue.empty() || quit.load(); });

                if (quit.load())
                    break;

                cmd = commandQueue.front();
                commandQueue.pop();
            }

            // No try-catch, just call the function directly
            process_uci_command(cmd);
        }
    }

    // Best move callback function
    void (*bestMoveCallback)(const char *move) = nullptr;
}

extern "C"
{

    void fs_init(const char *variantName)
    {
        if (initialized.exchange(true))
            return;

        // No try-catch, just perform the operations directly
        // Initialize engine components
        CommandLine::init(0, nullptr);
        UCI::init(Options);

        // Set variant if specified
        if (variantName && *variantName)
        {
            std::string variantStr(variantName);
            Options["UCI_Variant"] = variantStr;
        }

        PSQT::init(variants.find(Options["UCI_Variant"])->second);
        Bitboards::init();
        Position::init();
        Endgames::init();
        Threads.set(size_t(Options["Threads"]));
        Search::clear();

        // Start command processing thread
        quit.store(false);
        commandThread = new std::thread(command_thread_func);

        // Ensure engine is ready
        {
            std::unique_lock<std::mutex> lock(apiMutex);
            fs_command("isready");
            apiCV.wait_for(lock, std::chrono::seconds(2), []
                           { return true; });
        }
    }

    void fs_command(const char *cmd)
    {
        if (!initialized.load())
            fs_init(nullptr);

        if (!cmd)
            return; // Avoid nullptr segfaults

        std::string cmdStr(cmd);

        {
            std::lock_guard<std::mutex> lock(queueMutex);
            commandQueue.push(cmdStr);
        }
        queueCV.notify_one();
    }

    void fs_set_option(const char *name, const char *value)
    {
        if (!initialized.load())
            fs_init(nullptr);

        if (!name || !value)
            return; // Avoid nullptr segfaults

        std::string cmd = std::string("setoption name ") + name + " value " + value;
        fs_command(cmd.c_str());
    }

    void fs_set_position(const char *fen)
    {
        if (!initialized.load())
            fs_init(nullptr);

        if (!fen)
            return; // Avoid nullptr segfaults

        std::string cmd = std::string("position fen ") + fen;
        fs_command(cmd.c_str());
    }

    void fs_set_position_after_moves(const char *fen, const char *moves)
    {
        if (!initialized.load())
            fs_init(nullptr);

        if (!fen || !moves)
            return; // Avoid nullptr segfaults

        std::string cmd = std::string("position fen ") + fen + " moves " + moves;
        fs_command(cmd.c_str());
    }

    const char *fs_get_best_move(int time_ms)
    {
        if (!initialized.load())
            fs_init(nullptr);

        {
            std::lock_guard<std::mutex> lock(apiMutex);
            bestMoveReady = false;
        }

        std::string cmd = std::string("go movetime ") + std::to_string(time_ms);
        fs_command(cmd.c_str());

        {
            std::unique_lock<std::mutex> lock(apiMutex);
            if (!apiCV.wait_for(lock, std::chrono::milliseconds(time_ms * 2), []
                                { return bestMoveReady.load(); }))
            {
                // Timeout - provide a default move
                bestMove = "e2e4";
            }

            strncpy(moveBuffer, bestMove.c_str(), sizeof(moveBuffer) - 1);
            moveBuffer[sizeof(moveBuffer) - 1] = '\0';

            // Call the callback if registered
            if (bestMoveCallback)
                bestMoveCallback(moveBuffer);
        }

        return moveBuffer;
    }

    void fs_register_best_move_callback(void (*callback)(const char *move))
    {
        bestMoveCallback = callback;
    }

    void fs_quit(void)
    {
        if (!initialized.load())
            return;

        // Signal thread to quit and join
        quit.store(true);
        queueCV.notify_one();

        if (commandThread && commandThread->joinable())
        {
            commandThread->join();
            delete commandThread;
            commandThread = nullptr;
        }

        // Stop engine threads
        Threads.set(0);

        initialized.store(false);
    }

} // extern "C"