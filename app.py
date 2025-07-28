from flask import Flask

app = Flask(__name__)

@app.route("/")
def home():
    return "<h1>Hello from your ECS app! 🚀</h1> after change in jenkins and it is working in prod"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
