package conditional_meta_plugin

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestConditionalMeta(t *testing.T) {
	cfg := CreateConfig()
	
	ctx := context.Background()
	next := http.HandlerFunc(func(rw http.ResponseWriter, req *http.Request) {
		rw.Header().Set("Content-Type", "application/json")
		rw.WriteHeader(http.StatusOK)
		_, _ = rw.Write([]byte(`{"data": "test", "status": "ok"}`))
	})

	handler, err := New(ctx, next, cfg, "conditional-meta-test")
	if err != nil {
		t.Fatal(err)
	}

	t.Run("should add metadata when query parameter matches", func(t *testing.T) {
		recorder := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, "/test?include=meta", nil)

		handler.ServeHTTP(recorder, req)

		if recorder.Code != http.StatusOK {
			t.Errorf("Expected status %d, got %d", http.StatusOK, recorder.Code)
		}

		var response map[string]interface{}
		if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
			t.Fatalf("Failed to parse JSON response: %v", err)
		}

		// Check if metadata was added
		meta, exists := response["meta"]
		if !exists {
			t.Error("Expected 'meta' field in response")
		}

		metaMap, ok := meta.(map[string]interface{})
		if !ok {
			t.Error("Expected 'meta' to be an object")
		}

		routeName, exists := metaMap["route_name"]
		if !exists {
			t.Error("Expected 'route_name' field in meta")
		}

		if routeName != "v2-translate" {
			t.Errorf("Expected route_name to be 'v2-translate', got %v", routeName)
		}

		// Check original data is preserved
		if response["data"] != "test" {
			t.Error("Original data was not preserved")
		}
		if response["status"] != "ok" {
			t.Error("Original status was not preserved")
		}
	})

	t.Run("should not add metadata when query parameter doesn't match", func(t *testing.T) {
		recorder := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, "/test", nil)

		handler.ServeHTTP(recorder, req)

		if recorder.Code != http.StatusOK {
			t.Errorf("Expected status %d, got %d", http.StatusOK, recorder.Code)
		}

		var response map[string]interface{}
		if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
			t.Fatalf("Failed to parse JSON response: %v", err)
		}

		// Check if metadata was NOT added
		_, exists := response["meta"]
		if exists {
			t.Error("Did not expect 'meta' field in response")
		}

		// Check original data is preserved
		if response["data"] != "test" {
			t.Error("Original data was not preserved")
		}
		if response["status"] != "ok" {
			t.Error("Original status was not preserved")
		}
	})

	t.Run("should not modify non-JSON responses", func(t *testing.T) {
		// Create a handler that returns non-JSON content
		nonJSONNext := http.HandlerFunc(func(rw http.ResponseWriter, req *http.Request) {
			rw.Header().Set("Content-Type", "text/plain")
			rw.WriteHeader(http.StatusOK)
			_, _ = rw.Write([]byte("Hello, World!"))
		})

		handler, err := New(ctx, nonJSONNext, cfg, "conditional-meta-test")
		if err != nil {
			t.Fatal(err)
		}

		recorder := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, "/test?include=meta", nil)

		handler.ServeHTTP(recorder, req)

		if recorder.Code != http.StatusOK {
			t.Errorf("Expected status %d, got %d", http.StatusOK, recorder.Code)
		}

		body := recorder.Body.String()
		if body != "Hello, World!" {
			t.Errorf("Expected 'Hello, World!', got %s", body)
		}
	})
}

func TestCustomConfig(t *testing.T) {
	cfg := &Config{
		QueryParam: "custom",
		QueryValue: "data",
		MetaData: map[string]interface{}{
			"custom": map[string]interface{}{
				"test": "value",
			},
		},
	}

	ctx := context.Background()
	next := http.HandlerFunc(func(rw http.ResponseWriter, req *http.Request) {
		rw.Header().Set("Content-Type", "application/json")
		rw.WriteHeader(http.StatusOK)
		_, _ = rw.Write([]byte(`{"original": "data"}`))
	})

	handler, err := New(ctx, next, cfg, "conditional-meta-test")
	if err != nil {
		t.Fatal(err)
	}

	recorder := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/test?custom=data", nil)

	handler.ServeHTTP(recorder, req)

	if recorder.Code != http.StatusOK {
		t.Errorf("Expected status %d, got %d", http.StatusOK, recorder.Code)
	}

	var response map[string]interface{}
	if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
		t.Fatalf("Failed to parse JSON response: %v", err)
	}

	// Check if custom metadata was added
	custom, exists := response["custom"]
	if !exists {
		t.Error("Expected 'custom' field in response")
	}

	customMap, ok := custom.(map[string]interface{})
	if !ok {
		t.Error("Expected 'custom' to be an object")
	}

	testValue, exists := customMap["test"]
	if !exists {
		t.Error("Expected 'test' field in custom metadata")
	}

	if testValue != "value" {
		t.Errorf("Expected test value to be 'value', got %v", testValue)
	}
}
