package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// Configuration
var (
	addr           = flag.String("addr", ":8080", "http service address")
	statusFilePath = flag.String("status-file", "/home/coder/loading/loading-status.txt", "path to status file")
	htmlPath       = flag.String("html", "/home/coder/loading/loading.html", "path to html file")
	checkInterval  = flag.Duration("check-interval", 1*time.Second, "interval to check status file")
)

// ClientManager keeps track of all connected websocket clients
type ClientManager struct {
	clients    map[*websocket.Conn]bool
	broadcast  chan []byte
	register   chan *websocket.Conn
	unregister chan *websocket.Conn
	mutex      sync.Mutex
}

// WebsocketMessage is the structure of messages sent to clients
type WebsocketMessage struct {
	Type    string `json:"type"`
	Content string `json:"content"`
}

var manager = ClientManager{
	clients:    make(map[*websocket.Conn]bool),
	broadcast:  make(chan []byte),
	register:   make(chan *websocket.Conn),
	unregister: make(chan *websocket.Conn),
}

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all connections
	},
}

// Start the client manager to handle websocket connections
func (manager *ClientManager) start() {
	for {
		select {
		case conn := <-manager.register:
			manager.mutex.Lock()
			manager.clients[conn] = true
			manager.mutex.Unlock()
			
			// Send initial status upon connection
			status, err := readStatusFile()
			if err == nil {
				message := WebsocketMessage{
					Type:    "status",
					Content: status,
				}
				data, _ := json.Marshal(message)
				conn.WriteMessage(websocket.TextMessage, data)
			}
			
		case conn := <-manager.unregister:
			manager.mutex.Lock()
			if _, ok := manager.clients[conn]; ok {
				delete(manager.clients, conn)
				conn.Close()
			}
			manager.mutex.Unlock()
			
		case message := <-manager.broadcast:
			manager.mutex.Lock()
			for conn := range manager.clients {
				err := conn.WriteMessage(websocket.TextMessage, message)
				if err != nil {
					conn.Close()
					delete(manager.clients, conn)
				}
			}
			manager.mutex.Unlock()
		}
	}
}

// Handle websocket connections
func wsHandler(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("Websocket upgrade failed:", err)
		return
	}

	manager.register <- conn

	// Simple ping-pong to keep the connection alive
	go func() {
		for {
			_, _, err := conn.ReadMessage()
			if err != nil {
				manager.unregister <- conn
				break
			}
		}
	}()
}

// Read status file content
func readStatusFile() (string, error) {
	content, err := ioutil.ReadFile(*statusFilePath)
	if err != nil {
		return "", err
	}
	return string(content), nil
}

// Check if code-server is running
func isCodeServerRunning() bool {
	// Try to detect if code-server is running on the same port
	// by checking for a specific endpoint or header
	client := &http.Client{
		Timeout: 1 * time.Second,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			return http.ErrUseLastResponse // Don't follow redirects
		},
	}
	
	resp, err := client.Get("http://localhost:8080/")
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	
	// Check for code-server specific headers or content
	contentType := resp.Header.Get("Content-Type")
	if strings.Contains(contentType, "text/html") {
		// If we can access the root and it returns HTML, it might be code-server
		body, err := ioutil.ReadAll(resp.Body)
		if err == nil {
			bodyStr := string(body)
			return strings.Contains(bodyStr, "code-server") || 
			       strings.Contains(bodyStr, "vscode") || 
			       !strings.Contains(bodyStr, "Loading status")
		}
	}
	
	return false
}

// Monitor status file for changes and check if code-server is running
func monitorStatus() {
	var lastContent string
	var lastCodeServerCheck time.Time
	
	for {
		currentContent, err := readStatusFile()
		
		// Check for code-server running every 5 seconds
		if time.Since(lastCodeServerCheck) > 5*time.Second {
			lastCodeServerCheck = time.Now()
			
			if isCodeServerRunning() {
				// Notify clients that code-server is ready
				message := WebsocketMessage{
					Type:    "redirect",
					Content: "/",
				}
				data, _ := json.Marshal(message)
				manager.broadcast <- data
			}
		}
		
		if err == nil && currentContent != lastContent {
			lastContent = currentContent
			
			// Broadcast status update to all clients
			message := WebsocketMessage{
				Type:    "status",
				Content: currentContent,
			}
			data, _ := json.Marshal(message)
			manager.broadcast <- data
		}
		
		time.Sleep(*checkInterval)
	}
}

// Serve static files
func serveStatic(w http.ResponseWriter, r *http.Request) {
	// Special case for status file
	if r.URL.Path == "/loading-status.txt" {
		content, err := readStatusFile()
		if err != nil {
			http.Error(w, "Status not available", http.StatusInternalServerError)
			return
		}
		
		w.Header().Set("Content-Type", "text/plain")
		w.Write([]byte(content))
		return
	}
	
	// For all other paths, serve the loading HTML
	content, err := ioutil.ReadFile(*htmlPath)
	if err != nil {
		http.Error(w, "File not found", http.StatusNotFound)
		return
	}
	
	contentType := "text/html"
	if filepath.Ext(r.URL.Path) == ".css" {
		contentType = "text/css"
	} else if filepath.Ext(r.URL.Path) == ".js" {
		contentType = "application/javascript"
	}
	
	w.Header().Set("Content-Type", contentType)
	w.Write(content)
}

func main() {
	flag.Parse()
	
	// Create directory for status file if it doesn't exist
	dir := filepath.Dir(*statusFilePath)
	if _, err := os.Stat(dir); os.IsNotExist(err) {
		os.MkdirAll(dir, 0755)
	}
	
	// Initialize status file if needed
	if _, err := os.Stat(*statusFilePath); os.IsNotExist(err) {
		ioutil.WriteFile(*statusFilePath, []byte("Loading status... Server starting..."), 0644)
	}
	
	// Start the websocket manager
	go manager.start()
	
	// Start monitoring the status file
	go monitorStatus()
	
	// Set up HTTP handlers
	http.HandleFunc("/ws", wsHandler)
	http.HandleFunc("/", serveStatic)
	
	// Start HTTP server
	fmt.Printf("Starting status server on %s\n", *addr)
	err := http.ListenAndServe(*addr, nil)
	if err != nil {
		log.Fatal("HTTP server error: ", err)
	}
} 