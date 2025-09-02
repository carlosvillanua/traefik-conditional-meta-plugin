// Package conditionalmeta adds conditional metadata to JSON responses.
package conditionalmeta

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"strings"
)

// Config holds the plugin configuration.
type Config struct {
	// QueryParam is the query parameter to check for (default: "include")
	QueryParam string `json:"queryParam,omitempty"`
	// QueryValue is the value to match (default: "meta")
	QueryValue string `json:"queryValue,omitempty"`
	// MetaData is the JSON object to merge into the response
	MetaData map[string]interface{} `json:"metaData,omitempty"`
}

// CreateConfig creates and initializes the plugin configuration.
func CreateConfig() *Config {
	return &Config{
		QueryParam: "include",
		QueryValue: "meta",
		MetaData: map[string]interface{}{
			"meta": map[string]interface{}{
				"route_name": "v2-translate",
			},
		},
	}
}

type conditionalMeta struct {
	name   string
	next   http.Handler
	config *Config
}

// New creates and returns a new conditional meta plugin instance.
func New(_ context.Context, next http.Handler, config *Config, name string) (http.Handler, error) {
	// Validate configuration
	if config.QueryParam == "" {
		config.QueryParam = "include"
	}
	if config.QueryValue == "" {
		config.QueryValue = "meta"
	}
	if config.MetaData == nil {
		config.MetaData = map[string]interface{}{
			"meta": map[string]interface{}{
				"route_name": "v2-translate",
			},
		}
	}

	return &conditionalMeta{
		name:   name,
		next:   next,
		config: config,
	}, nil
}

func (c *conditionalMeta) ServeHTTP(rw http.ResponseWriter, req *http.Request) {
	// Check if we need to add metadata
	shouldAddMeta := req.URL.Query().Get(c.config.QueryParam) == c.config.QueryValue

	if !shouldAddMeta {
		// No metadata needed, pass through
		c.next.ServeHTTP(rw, req)
		return
	}

	// We need to intercept and modify the response
	wrappedWriter := &responseWriter{
		ResponseWriter: rw,
		config:        c.config,
	}

	c.next.ServeHTTP(wrappedWriter, req)

	// Process the buffered response
	bodyBytes := wrappedWriter.buffer.Bytes()

	// Check if response is JSON
	contentType := wrappedWriter.Header().Get("Content-Type")
	if !isJSONContentType(contentType) {
		// Not JSON, write as-is
		if _, err := rw.Write(bodyBytes); err != nil {
			log.Printf("unable to write body: %v", err)
		}
		return
	}

	// Parse and merge JSON
	modifiedBody, err := c.mergeJSONMetadata(bodyBytes)
	if err != nil {
		log.Printf("error merging JSON metadata: %v", err)
		// Write original body on error
		if _, err := rw.Write(bodyBytes); err != nil {
			log.Printf("unable to write original body: %v", err)
		}
		return
	}

	// Write the modified response
	if _, err := rw.Write(modifiedBody); err != nil {
		log.Printf("unable to write modified body: %v", err)
	}
}

func (c *conditionalMeta) mergeJSONMetadata(body []byte) ([]byte, error) {
	// Parse the original JSON response
	var originalResponse map[string]interface{}
	if err := json.Unmarshal(body, &originalResponse); err != nil {
		return nil, fmt.Errorf("failed to parse JSON response: %w", err)
	}

	// Merge metadata
	for key, value := range c.config.MetaData {
		originalResponse[key] = value
	}

	// Marshal back to JSON
	modifiedJSON, err := json.Marshal(originalResponse)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal modified JSON: %w", err)
	}

	return modifiedJSON, nil
}

func isJSONContentType(contentType string) bool {
	return strings.Contains(strings.ToLower(contentType), "application/json") ||
		strings.Contains(strings.ToLower(contentType), "text/json")
}

type responseWriter struct {
	buffer       bytes.Buffer
	wroteHeader  bool
	config       *Config

	http.ResponseWriter
}

func (r *responseWriter) WriteHeader(statusCode int) {
	r.wroteHeader = true
	
	// Remove Content-Length header as we'll modify the body
	r.ResponseWriter.Header().Del("Content-Length")
	
	r.ResponseWriter.WriteHeader(statusCode)
}

func (r *responseWriter) Write(p []byte) (int, error) {
	if !r.wroteHeader {
		r.WriteHeader(http.StatusOK)
	}

	// Buffer the response body
	return r.buffer.Write(p)
}

func (r *responseWriter) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	hijacker, ok := r.ResponseWriter.(http.Hijacker)
	if !ok {
		return nil, nil, fmt.Errorf("the ResponseWriter doesn't support the Hijacker interface")
	}
	return hijacker.Hijack()
}
