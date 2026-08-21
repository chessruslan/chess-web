import atexit
import math
import threading

import chess
import chess.engine
from flask import Flask, jsonify, request

app = Flask(__name__)
engine = chess.engine.SimpleEngine.popen_uci("/usr/games/stockfish")
engine.configure({"Threads": 2, "Hash": 256, "UCI_ShowWDL": True})
engine_lock = threading.Lock()


@atexit.register
def close_engine():
    try:
        engine.quit()
    except Exception:
        pass


@app.after_request
def cors(response):
    response.headers["Access-Control-Allow-Origin"] = "https://makechess.com"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type"
    response.headers["Access-Control-Allow-Methods"] = "POST, OPTIONS"
    return response


@app.route("/v1", methods=["POST", "OPTIONS"])
def analyse():
    if request.method == "OPTIONS":
        return "", 204

    body = request.get_json(force=True)
    fen = str(body.get("fen", "")).strip()
    depth = max(1, min(int(body.get("depth", 18)), 24))
    variants = max(1, min(int(body.get("variants", body.get("multiPv", 1))), 5))
    think_ms = max(100, min(int(body.get("maxThinkingTime", 2000)), 10000))

    try:
        board = chess.Board(fen)
    except ValueError as error:
        return jsonify(error=f"Invalid FEN: {error}"), 400

    limit = chess.engine.Limit(depth=depth, time=think_ms / 1000)
    with engine_lock:
        results = engine.analyse(board, limit, multipv=variants)

    lines = []
    for result in results:
        pv = result.get("pv", [])
        uci_moves = [move.uci() for move in pv]
        # The Flutter evaluation bar always expects White's point of view.
        score = result["score"].pov(chess.WHITE)
        cp = score.score()
        mate = score.mate()
        eval_pawns = (cp / 100) if cp is not None else None
        wdl = result.get("wdl")
        white_wdl = wdl.pov(chess.WHITE) if wdl is not None else None
        lines.append({
            "uci": uci_moves[0] if uci_moves else "",
            "move": uci_moves[0] if uci_moves else "",
            "pv": " ".join(uci_moves),
            "line": uci_moves,
            "centipawns": cp,
            "mate": mate,
            "depth": result.get("depth"),
            "seldepth": result.get("seldepth"),
            "nodes": result.get("nodes"),
            "nps": result.get("nps"),
            "hashfull": result.get("hashfull"),
            "tbhits": result.get("tbhits"),
            "eval": eval_pawns,
            "score": {"type": "mate" if mate is not None else "cp", "value": mate if mate is not None else cp},
            "wdl": ({"wins": white_wdl.wins, "draws": white_wdl.draws, "losses": white_wdl.losses} if white_wdl is not None else None),
        })

    first = lines[0] if lines else {}
    cp = first.get("centipawns")
    evaluation = (cp / 100) if cp is not None else None
    if first.get("wdl") is not None:
        wdl = first["wdl"]
        win_chance = round((wdl["wins"] + wdl["draws"] / 2) / 10, 1)
    elif evaluation is not None:
        win_chance = round(100 / (1 + math.exp(-evaluation * 0.9)), 1)
    else:
        win_chance = None

    return jsonify({
        "fen": board.fen(),
        "turn": "white" if board.turn == chess.WHITE else "black",
        "move": first.get("move", ""),
        "uci": first.get("uci", ""),
        "best": first.get("uci", ""),
        "pv": first.get("pv", ""),
        "centipawns": first.get("centipawns"),
        "mate": first.get("mate"),
        "depth": first.get("depth", depth),
        "eval": evaluation,
        "score": first.get("score"),
        "winChance": win_chance,
        "seldepth": first.get("seldepth"),
        "nodes": first.get("nodes"),
        "nps": first.get("nps"),
        "hashfull": first.get("hashfull"),
        "tbhits": first.get("tbhits"),
        "lines": lines,
        "variants": lines,
        "text": f"Best move: {first.get('uci', '')}",
    })


@app.get("/health")
def health():
    return jsonify(ok=True)
