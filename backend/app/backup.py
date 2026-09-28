"""Consistent BSON backup and restore into a NEW restore_* database.

Usage: python -m app.backup backup <directory>
       python -m app.backup restore <directory> restore_<name>
"""

import argparse
import gzip
import re
from pathlib import Path

from bson import BSON, decode_file_iter, json_util
from pymongo.read_concern import ReadConcern

from app.config import get_settings
from app.database import MongoDatabase


def backup(database, destination):
    destination = Path(destination)
    destination.mkdir(parents=True, exist_ok=False)
    collections = [
        name
        for name in database.database.list_collection_names()
        if not name.startswith("system.")
    ]
    metadata = {"database": database.database.name, "collections": {}}
    with database.client.start_session() as session:
        with session.start_transaction(read_concern=ReadConcern("snapshot")):
            for number, name in enumerate(collections):
                filename = f"{number:04d}.bson.gz"
                metadata["collections"][name] = {
                    "file": filename,
                    "indexes": list(database.database[name].list_indexes()),
                }
                with gzip.open(destination / filename, "wb") as stream:
                    for document in database.database[name].find({}, session=session):
                        stream.write(BSON.encode(document))
    (destination / "manifest.json").write_text(
        json_util.dumps(metadata), encoding="utf-8"
    )


def restore(client, source, target):
    if not re.fullmatch(r"restore_[A-Za-z0-9_]+", target):
        raise ValueError("Restore requires a new database named restore_<name>")
    if target in client.list_database_names():
        raise ValueError("Destination exists; refusing to overwrite it")
    source = Path(source).resolve()
    metadata = json_util.loads((source / "manifest.json").read_text(encoding="utf-8"))
    for name, collection in metadata["collections"].items():
        path = (source / collection["file"]).resolve()
        if path.parent != source:
            raise ValueError("Invalid archive path")
        client[target].create_collection(name)
        with gzip.open(path, "rb") as stream:
            batch = []
            for document in decode_file_iter(stream):
                batch.append(document)
                if len(batch) == 1000:
                    client[target][name].insert_many(batch)
                    batch = []
            if batch:
                client[target][name].insert_many(batch)
        for index in collection["indexes"]:
            if index["name"] == "_id_":
                continue
            options = {k: v for k, v in index.items() if k not in {"key", "v", "ns"}}
            client[target][name].create_index(list(index["key"].items()), **options)
    return {
        name: client[target][name].count_documents({})
        for name in metadata["collections"]
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["backup", "restore"])
    parser.add_argument("directory")
    parser.add_argument("target", nargs="?")
    args = parser.parse_args()
    database = MongoDatabase(get_settings())
    try:
        if args.action == "backup":
            backup(database, args.directory)
            print(
                "Backup complete. Protect the archive and retain encryption keys separately."
            )
        else:
            print(restore(database.client, args.directory, args.target or ""))
    finally:
        database.close()


if __name__ == "__main__":
    main()
