import os
from flask import Flask, render_template

APP_HOST  = os.environ['APP_HOST'] if 'APP_HOST' in os.environ else '127.0.0.1'
APP_PORT  = os.environ['APP_PORT'] if 'APP_PORT' in os.environ else 5000
APP_DEBUG = bool(os.environ['APP_DEBUG']) if 'APP_DEBUG' in os.environ else False

app = Flask(__name__)

@app.route('/')
def home():
	return render_template('index.html')

@app.route('/healthz')
def healthz():
	return ''

if __name__ == '__main__':
	app.run(host=APP_HOST, port=APP_PORT, debug=APP_DEBUG)
