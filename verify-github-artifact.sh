#!/bin/bash
# Script to download and verify GitHub artifacts using sigstore/attestation
# Based on: Checking artifacts from GitHub with sigstore.md

set -euo pipefail

# Default values
OWNER="stalwartlabs"
REPO="stalwart"
VERSION="v0.13.1"
ARTIFACT="stalwart-x86_64-unknown-linux-gnu.tar.gz"
EXTRACT_BINARY=""
VERIFY_BINARY=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Download and verify GitHub release artifacts using sigstore attestation.

OPTIONS:
    -o, --owner OWNER           GitHub repository owner (default: $OWNER)
    -r, --repo REPO             GitHub repository name (default: $REPO)
    -v, --version VERSION       Release version tag (default: $VERSION)
    -a, --artifact ARTIFACT     Artifact filename (default: $ARTIFACT)
    -b, --binary BINARY         Binary name to extract and verify from tarball
    -h, --help                  Show this help message

EXAMPLES:
    # Use defaults (Stalwart v0.13.1)
    $0

    # Download and verify a different version
    $0 -v v0.14.0

    # Verify different artifact
    $0 -o myorg -r myrepo -v v1.0.0 -a myapp-linux-amd64.tar.gz

    # Also verify the binary inside the tarball
    $0 -b stalwart

REQUIREMENTS:
    - wget or curl
    - gh (GitHub CLI v2.81.0+ with attestation support for binaries)
    - tar (if extracting binaries)
    - shasum (optional, for manual checksum verification)

EOF
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--owner)
            OWNER="$2"
            shift 2
            ;;
        -r|--repo)
            REPO="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -a|--artifact)
            ARTIFACT="$2"
            shift 2
            ;;
        -b|--binary)
            EXTRACT_BINARY="$2"
            VERIFY_BINARY=true
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Check prerequisites
check_prerequisites() {
    local missing_tools=()

    if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
        missing_tools+=("wget or curl")
    fi

    if ! command -v gh &> /dev/null; then
        missing_tools+=("gh (GitHub CLI v2.81.0+)")
    fi

    if [[ $VERIFY_BINARY == true ]] && ! command -v tar &> /dev/null; then
        missing_tools+=("tar")
    fi

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo -e "${RED}Error: Missing required tools:${NC}"
        printf '%s\n' "${missing_tools[@]}"
        echo ""
        echo "Install missing tools:"
        echo "  - wget: apt install wget / brew install wget"
        echo "  - gh v2.81.0+: https://github.com/cli/cli/releases"
        echo "  - tar: usually pre-installed"
        exit 1
    fi

    # Check gh version for binary attestation support
    if command -v gh &> /dev/null; then
        local gh_version=$(gh --version | head -n1 | awk '{print $3}')
        echo -e "${YELLOW}Detected gh version: $gh_version${NC}"
        echo ""
    fi
}

# Download artifact
download_artifact() {
    local url="https://github.com/${OWNER}/${REPO}/releases/download/${VERSION}/${ARTIFACT}"

    echo -e "${YELLOW}Downloading artifact...${NC}"
    echo "URL: $url"

    if [[ -f "$ARTIFACT" ]]; then
        echo -e "${YELLOW}Warning: $ARTIFACT already exists. Skipping download.${NC}"
        return 0
    fi

    if command -v wget &> /dev/null; then
        wget "$url"
    else
        curl -L -O "$url"
    fi

    echo -e "${GREEN}✓ Download complete${NC}"
    echo ""
}

# Calculate SHA256 checksum (optional reference)
calculate_checksum() {
    local file="$1"

    if ! command -v shasum &> /dev/null; then
        echo -e "${YELLOW}Note: shasum not available, skipping manual checksum${NC}"
        echo ""
        return 0
    fi

    echo -e "${YELLOW}Calculating SHA256 checksum (reference)...${NC}"
    local checksum=$(shasum -a 256 "$file")
    echo "$checksum"
    echo ""
}

# Verify attestation using GitHub CLI
verify_attestation() {
    echo -e "${YELLOW}Verifying attestation with GitHub CLI...${NC}"
    echo "Owner: $OWNER"
    echo "Artifact: $ARTIFACT"
    echo ""

    if gh attestation verify --owner "$OWNER" "$ARTIFACT"; then
        echo ""
        echo -e "${GREEN}✓ Attestation verification succeeded!${NC}"
        return 0
    else
        echo ""
        echo -e "${RED}✗ Attestation verification failed!${NC}"
        return 1
    fi
}

# Extract and verify binary from tarball
verify_binary() {
    if [[ $VERIFY_BINARY == false ]]; then
        return 0
    fi

    echo ""
    echo -e "${YELLOW}Extracting and verifying binary: $EXTRACT_BINARY${NC}"

    if [[ ! "$ARTIFACT" =~ \.tar\.gz$ ]] && [[ ! "$ARTIFACT" =~ \.tgz$ ]]; then
        echo -e "${YELLOW}Warning: Artifact doesn't appear to be a tarball. Skipping binary extraction.${NC}"
        return 0
    fi

    tar xvf "$ARTIFACT" "$EXTRACT_BINARY" 2>/dev/null || {
        echo -e "${YELLOW}Warning: Could not extract $EXTRACT_BINARY from tarball${NC}"
        return 0
    }

    if [[ -f "$EXTRACT_BINARY" ]]; then
        echo ""
        calculate_checksum "$EXTRACT_BINARY"
        echo -e "${GREEN}✓ Binary extracted${NC}"

        # Verify binary attestation with gh CLI (v2.81.0+ feature)
        echo ""
        echo -e "${YELLOW}Verifying binary attestation with GitHub CLI...${NC}"
        echo "Owner: $OWNER"
        echo "Binary: $EXTRACT_BINARY"
        echo ""

        if gh attestation verify --owner "$OWNER" "$EXTRACT_BINARY"; then
            echo ""
            echo -e "${GREEN}✓ Binary attestation verification succeeded!${NC}"
        else
            echo ""
            echo -e "${RED}✗ Binary attestation verification failed!${NC}"
            echo -e "${YELLOW}Note: This requires gh CLI v2.81.0 or later${NC}"
        fi

        # Run binary with --version to verify it works and check version
        echo ""
        echo -e "${YELLOW}Running binary with --version...${NC}"
        chmod +x "$EXTRACT_BINARY"
        if ./"$EXTRACT_BINARY" --version; then
            echo ""
            echo -e "${GREEN}✓ Binary executed successfully${NC}"
            echo -e "${YELLOW}Note: Verify the version above matches expected version: $VERSION${NC}"
        else
            echo ""
            echo -e "${RED}✗ Warning: Binary failed to execute or report version${NC}"
        fi
    fi
}

# Main execution
main() {
    echo "========================================="
    echo "GitHub Artifact Verification with Sigstore"
    echo "========================================="
    echo ""

    check_prerequisites
    download_artifact
    calculate_checksum "$ARTIFACT"
    verify_attestation
    verify_binary

    echo ""
    echo -e "${GREEN}All verification steps completed successfully!${NC}"
}

main
