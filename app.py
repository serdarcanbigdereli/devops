from flask import Flask
app = Flask(__name__)

@app.route('/')
def index():
    return "Hello Hepsiburada from Ufkun"

@app.route('/user/<name>')
def user(name):
	return 'Hello Hepsiburada from {0}'.format(name)


if __name__ == '__main__':
    app.run(host="0.0.0.0",port=11130)

