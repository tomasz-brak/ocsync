from hashlib import md5
import io
import string
from typing import Dict
from pathlib import Path
from flask import Flask, Response, jsonify
from logging import Logger, INFO
import glob


app = Flask(__name__)


@app.route("/filelist")  # type: ignore
def genFilelist():
    files: Dict[str, str] = {}

    for file in glob.iglob("./sync/**/*", recursive=True):
        file = Path(file)
        print(f"Now reading: {file}")
        if file.is_dir():
            continue
        with open(file, "rb") as fileContent:
            files[file.as_posix()] = (md5(fileContent.read()).hexdigest()).upper()
    return files


@app.route("/fetchfile/<path:filepath>")
def getfile(filepath):
    with io.open((Path(filepath)), "rt", encoding="utf-8", newline="") as f:
        file_content = f.read()
        print(f"content {repr(file_content)}")
    return Response(response=file_content, status=200, mimetype="text/plain")


app.run("0.0.0.0", 51820, debug=True)
