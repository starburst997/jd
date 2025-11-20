#!/usr/bin/env bash

show_pg_help() {
    cat << EOF
Usage: jd pg [options]

Open a port-forward connection to PostgreSQL database cluster.

This command forwards local port 5432 to the postgres-rw service in the
postgres namespace, allowing you to connect to the database using:
  psql -h localhost -p 5432 -U <username> <database>

Options:
  --help              Show this help message

Dependencies:
  - kubectl: Required to create port-forward connection

Example:
  jd pg                           # Start port-forward (Ctrl+C to stop)
  jd pg &                         # Run in background
EOF
}

execute_command() {
    # Check for kubectl dependency
    check_command_dependencies "pg"

    # Check if we're in a kubernetes context
    if ! kubectl config current-context &>/dev/null; then
        error "No active Kubernetes context found"
        info "Configure kubectl to connect to your cluster first"
        return 1
    fi

    # Check if postgres namespace exists
    if ! kubectl get namespace postgres &>/dev/null; then
        error "Namespace 'postgres' not found in current cluster"
        info "Available namespaces:"
        kubectl get namespaces --no-headers -o custom-columns=":metadata.name" 2>/dev/null | sed 's/^/  - /'
        return 1
    fi

    # Check if service exists
    if ! kubectl get svc postgres-rw -n postgres &>/dev/null; then
        error "Service 'postgres-rw' not found in namespace 'postgres'"
        info "Available services in postgres namespace:"
        kubectl get svc -n postgres --no-headers -o custom-columns=":metadata.name" 2>/dev/null | sed 's/^/  - /'
        return 1
    fi

    info "Starting port-forward to PostgreSQL (port 5432)"
    info "Press Ctrl+C to stop the port-forward"
    echo ""
    info "Connect using: psql -h localhost -p 5432 -U <username> <database>"
    echo ""

    # Execute the port-forward
    kubectl port-forward -n postgres svc/postgres-rw 5432:5432
}
