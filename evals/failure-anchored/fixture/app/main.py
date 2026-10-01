import logging

from app import db

log = logging.getLogger("orders")


def main():
    logging.basicConfig(format="%(message)s", level=logging.INFO)
    log.info("starting orders service")
    log.info("connecting to database")
    conn = db.connect()
    log.info("connected; serving")
    conn.close()


if __name__ == "__main__":
    main()
