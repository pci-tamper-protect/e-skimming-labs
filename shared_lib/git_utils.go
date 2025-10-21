package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// GitInfo represents git commit information
type GitInfo struct {
	CommitSHA      string `json:"commit_sha"`
	CommitSHAShort string `json:"commit_sha_short"`
	CommitMessage  string `json:"commit_message"`
	CommitAuthor   string `json:"commit_author"`
	CommitDate     string `json:"commit_date"`
	Branch         string `json:"branch"`
	IsDirty        bool   `json:"is_dirty"`
	Source         string `json:"source"`
}

// DeploymentInfo represents deployment metadata
type DeploymentInfo struct {
	Deployment struct {
		Timestamp string `json:"timestamp"`
		Hostname  string `json:"hostname"`
		User      string `json:"user"`
	} `json:"deployment"`
	Git GitInfo `json:"git"`
}

// Global cache for git commit info to avoid repeated subprocess calls
var gitInfoCache *GitInfo
var commitShortCache string

// getGitCommitInfo gets git commit information with fallbacks for both development and production
func getGitCommitInfo() GitInfo {
	// Return cached result if available
	if gitInfoCache != nil {
		return *gitInfoCache
	}

	gitInfo := GitInfo{
		Source: "unknown",
	}

	// First try to load from deployment file (production scenario)
	deploymentInfoPath := filepath.Join(".", "deployment_info.json")
	if _, err := os.Stat(deploymentInfoPath); err == nil {
		if data, err := os.ReadFile(deploymentInfoPath); err == nil {
			var deploymentInfo DeploymentInfo
			if err := json.Unmarshal(data, &deploymentInfo); err == nil {
				gitInfo = deploymentInfo.Git
				gitInfo.Source = "deployment_file"
				gitInfoCache = &gitInfo
				return gitInfo
			}
		}
	}

	// Fallback to live git commands (development scenario)
	gitInfo = getGitInfoFromCommands()
	gitInfoCache = &gitInfo
	return gitInfo
}

// getGitInfoFromCommands executes git commands to get commit information
func getGitInfoFromCommands() GitInfo {
	gitInfo := GitInfo{
		Source: "not_git_repo",
	}

	// Check if we're in a git repository
	if err := exec.Command("git", "rev-parse", "--git-dir").Run(); err != nil {
		return gitInfo
	}

	// Get commit SHA
	if output, err := exec.Command("git", "rev-parse", "HEAD").Output(); err == nil {
		commitSHA := strings.TrimSpace(string(output))
		gitInfo.CommitSHA = commitSHA
		if len(commitSHA) >= 7 {
			gitInfo.CommitSHAShort = commitSHA[:7]
		}
	}

	// Get commit message (first line)
	if output, err := exec.Command("git", "log", "-1", "--pretty=format:%s").Output(); err == nil {
		gitInfo.CommitMessage = strings.TrimSpace(string(output))
	}

	// Get commit author
	if output, err := exec.Command("git", "log", "-1", "--pretty=format:%an").Output(); err == nil {
		gitInfo.CommitAuthor = strings.TrimSpace(string(output))
	}

	// Get commit date in ISO format
	if output, err := exec.Command("git", "log", "-1", "--pretty=format:%aI").Output(); err == nil {
		gitInfo.CommitDate = strings.TrimSpace(string(output))
	}

	// Get current branch
	if output, err := exec.Command("git", "rev-parse", "--abbrev-ref", "HEAD").Output(); err == nil {
		gitInfo.Branch = strings.TrimSpace(string(output))
	}

	// Check if working directory is dirty
	if err := exec.Command("git", "diff", "--quiet").Run(); err != nil {
		gitInfo.IsDirty = true
	} else if err := exec.Command("git", "diff", "--cached", "--quiet").Run(); err != nil {
		gitInfo.IsDirty = true
	}

	gitInfo.Source = "live_git"
	return gitInfo
}

// getCommitShortInfo returns a short string representation of the current commit
func getCommitShortInfo() string {
	// Return cached result if available
	if commitShortCache != "" {
		return commitShortCache
	}

	gitInfo := getGitCommitInfo()
	if gitInfo.CommitSHAShort != "" {
		commitShortCache = gitInfo.CommitSHAShort
	} else {
		commitShortCache = "unknown"
	}
	return commitShortCache
}

// createDeploymentInfo creates deployment information file with git and deployment metadata
func createDeploymentInfo(outputPath string) DeploymentInfo {
	if outputPath == "" {
		outputPath = "deployment_info.json"
	}

	deploymentInfo := DeploymentInfo{
		Deployment: struct {
			Timestamp string `json:"timestamp"`
			Hostname  string `json:"hostname"`
			User      string `json:"user"`
		}{
			Timestamp: time.Now().UTC().Format(time.RFC3339) + "Z",
			Hostname:  getEnvOrDefault("HOSTNAME", "unknown"),
			User:      getEnvOrDefault("USER", "unknown"),
		},
		Git: getGitCommitInfo(),
	}

	// Override source since we're creating it during deployment
	deploymentInfo.Git.Source = "deployment_capture"

	// Ensure parent directory exists
	if err := os.MkdirAll(filepath.Dir(outputPath), 0755); err != nil {
		log.Printf("⚠️ Failed to create parent directory for %s: %v", outputPath, err)
	}

	// Save deployment info
	if data, err := json.MarshalIndent(deploymentInfo, "", "  "); err == nil {
		if err := os.WriteFile(outputPath, data, 0644); err != nil {
			log.Printf("⚠️ Failed to save deployment info to %s: %v", outputPath, err)
			
			// Try fallback to current working directory
			fallbackPath := filepath.Join(".", "deployment_info.json")
			if err := os.WriteFile(fallbackPath, data, 0644); err != nil {
				log.Printf("❌ Fallback also failed: %v", err)
			} else {
				log.Printf("✅ Deployment info saved to fallback location: %s", fallbackPath)
			}
		} else {
			log.Printf("✅ Deployment info saved to %s", outputPath)
		}
	}

	return deploymentInfo
}

// logGitInfo logs git information to the application log
func logGitInfo() {
	gitInfo := getGitCommitInfo()
	commitDisplay := getCommitShortInfo()
	
	log.Printf("🔗 Git commit: %s", commitDisplay)
	log.Printf("🔗 Git info: commit=%s, branch=%s, author=%s, dirty=%t, source=%s", 
		gitInfo.CommitSHA, gitInfo.Branch, gitInfo.CommitAuthor, gitInfo.IsDirty, gitInfo.Source)
}

// getEnvOrDefault returns environment variable value or default
func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// getGitInfoForTemplate returns git info formatted for HTML templates
func getGitInfoForTemplate() map[string]interface{} {
	gitInfo := getGitCommitInfo()
	return map[string]interface{}{
		"CommitSHA":      gitInfo.CommitSHA,
		"CommitSHAShort": gitInfo.CommitSHAShort,
		"CommitMessage":  gitInfo.CommitMessage,
		"CommitAuthor":   gitInfo.CommitAuthor,
		"CommitDate":     gitInfo.CommitDate,
		"Branch":         gitInfo.Branch,
		"IsDirty":        gitInfo.IsDirty,
		"Source":         gitInfo.Source,
		"CommitDisplay":  getCommitShortInfo(),
	}
}
