#!/usr/bin/env bash

if [ -z ${EASTERN_STATE_BUCKET+x} ]; then
  echo "$(date) - Not using eastern_state"
else
  echo "$(date) - Installing environment variables using eastern_state - $EASTERN_STATE_ENV"
  source <(python3 -c "from eastern_state import main; main(['load_environment','$EASTERN_STATE_BUCKET','$EASTERN_STATE_NAME','$EASTERN_STATE_ENV'])")
fi

set -e

worker() {
  WORKERS_COUNT=${WORKERS_COUNT:-2}
  QUEUES=${QUEUES:-queries,scheduled_queries,celery}

  echo "Starting $WORKERS_COUNT workers for queues: $QUEUES..."
  exec /usr/local/bin/celery worker --app=redash.worker -c$WORKERS_COUNT -Q$QUEUES -linfo --maxtasksperchild=10 -Ofair
}

scheduler() {
  WORKERS_COUNT=${WORKERS_COUNT:-1}
  QUEUES=${QUEUES:-celery}

  echo "Starting scheduler and $WORKERS_COUNT workers for queues: $QUEUES..."

  exec /usr/local/bin/celery worker --app=redash.worker --beat -c$WORKERS_COUNT -Q$QUEUES -linfo --maxtasksperchild=10 -Ofair
}

server() {
  exec /usr/local/bin/gunicorn -b 0.0.0.0:5003 --worker-class=gevent --name redash -w4 redash.wsgi:app
}

help() {
  echo "Redash Docker."
  echo ""
  echo "Usage:"
  echo ""

  echo "server -- start Redash server (with gunicorn)"
  echo "worker -- start Celery worker"
  echo "scheduler -- start Celery worker with a beat (scheduler) process"
  echo ""
  echo "shell -- open shell"
  echo "dev_server -- start Flask development server with debugger and auto reload"
  echo "create_db -- create database tables"
  echo "manage -- CLI to manage redash"
}

tests() {
  export REDASH_DATABASE_URL="postgresql://postgres@postgres/tests"
  exec make test
}

case "$1" in
  worker)
    shift
    worker
    ;;
  server)
    shift
    server
    ;;
  scheduler)
    shift
    scheduler
    ;;
  dev_server)
    exec /app/manage.py runserver --debugger --reload -h 0.0.0.0
    ;;
  shell)
    exec /app/manage.py shell
    ;;
  create_db)
    exec /app/manage.py database create_tables
    ;;
  manage)
    shift
    exec /app/manage.py $*
    ;;
  tests)
    tests
    ;;
  *)
    help
    ;;
esac
