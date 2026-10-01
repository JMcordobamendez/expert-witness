import os


def load_template(name):
    path = os.path.join("templates", name)
    with open(path) as f:
        return f.read()


def main():
    page = load_template("index.html")
    print("serving", len(page), "bytes")


if __name__ == "__main__":
    main()
