#!/usr/bin/env python3
import http.server
import socketserver
import os
import sys

PORT = 8080

class LoadingHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory="/home/coder/loading", **kwargs)
    
    def log_message(self, format, *args):
        # Suppress log messages
        return

def run_server():
    with socketserver.TCPServer(("", PORT), LoadingHandler) as httpd:
        print(f"Serving loading page at port {PORT}")
        httpd.serve_forever()

if __name__ == "__main__":
    run_server() 