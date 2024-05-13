from flask import Flask, request
import json

app = Flask(__name__)

ALPHA_VALUE = 0.9
BETA_VALUE = 0.9
GAMMA_VALUE = 0.9

@app.route("/holt_winters")
def metric():
    app.logger.info('Received context: %s', request.data)

    return json.dumps({
        "alpha": ALPHA_VALUE,
        "beta": BETA_VALUE,
        "gamma": GAMMA_VALUE,
    })

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0")
