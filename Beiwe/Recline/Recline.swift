//
//  Recline.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/28/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import PromiseKit
import ObjectMapper

class ReclineObject : Mappable {
    private var _docRevision: CBLRevision?;

    init() {
    }

    required init?(_ map: Map) {
    }

    // Mappable
    func mapping(map: Map) {
    }

}

struct ReclineMetadata : Mappable {
    var type: String?;

    init(type: String) {
        self.type = type;
    }
    init?(_ map: Map) {

    }

    mutating func mapping(map: Map) {
        type        <- map["type"];
    }
}
enum ReclineErrors: ErrorType {
    case DatabaseNotOpen
}
class Recline {
    static let kReclineMetadataKey = "reclineMetadata";
    static let queue = dispatch_queue_create("com.rocketfarm.beiwe.recline.queue", nil)
    static let shared = Recline();
    var manager: CBLManager!;
    var db: CBLDatabase?;
    var typesView: CBLView?;

    init() {
    }

    func _open(dbName: String = "default") -> Promise<BooleanType> {
        return Promise { resolve, reject in
            self.db = try manager.databaseNamed(dbName);
            self.typesView = self.db!.viewNamed("reclineType")
            typesView!.setMapBlock({ (doc, emit) in
                if let reclineMeta = Mapper<ReclineMetadata>().map(doc[Recline.kReclineMetadataKey]) {
                    if let type = reclineMeta.type {
                        emit(type, Mapper<ReclineMetadata>().toJSON(reclineMeta));
                    }
                }
            }, version: "5")

            return resolve(true);
        }
    }

    func open(dbName: String = "default") -> Promise<BooleanType> {
        return Promise().then(on: Recline.queue) {
            if (self.manager == nil) {
                self.manager = CBLManager.sharedInstance()
                self.manager.dispatchQueue = Recline.queue
            }

            return self._open(dbName);
        }
    }

    func _save<T: ReclineObject>(obj: T) -> Promise<T> {
        return Promise { resolve, reject in
            guard let db = db else {
                return reject(ReclineErrors.DatabaseNotOpen);
            }

            var doc: CBLDocument?;
            if let rev = obj._docRevision {
                doc = rev.document;
            } else {
                doc = db.createDocument();
            }

            var newProps = Mapper<T>().toJSON(obj);
            let reclineMeta = ReclineMetadata(type: String(obj.dynamicType));
            newProps[Recline.kReclineMetadataKey] = Mapper<ReclineMetadata>().toJSON(reclineMeta);

            if let oldProps = doc?.properties {
                newProps["_rev"] = oldProps["_rev"];
                newProps["_id"] = oldProps["_id"];
                /*
                for (key, value) in oldProps {
                    newProps[key] = newProps[key] != nil ? newProps[key];
                }
                */
            }
            let savedRev = try doc?.putProperties(newProps);
            obj._docRevision = savedRev;

            return resolve(obj);

        }

    }

    func save<T: ReclineObject>(obj: T) -> Promise<T> {
        return Promise().then(on: Recline.queue) {
            return self._save(obj)
        }
    }


    func _load<T: ReclineObject>(docId: String) -> Promise<T?> {
        return Promise { resolve, reject in
            guard let db = db else {
                return reject(ReclineErrors.DatabaseNotOpen);
            }
            let doc: CBLDocument? = db.documentWithID(docId);
            if let doc = doc {
                if let newObj = Mapper<T>().map(doc.properties)  {
                    newObj._docRevision = doc.currentRevision;
                    return resolve(newObj);
                }
            }
            return resolve(nil);
        }
    }

    func load<T: ReclineObject>(docId: String) -> Promise<T?> {
        return Promise().then(on: Recline.queue) {
            self._load(docId);
        }
    }


    func _queryAll<T: ReclineObject>() -> Promise<[T]> {
        return Promise { resolve, reject in
            guard let typesView = typesView else {
                return reject(ReclineErrors.DatabaseNotOpen);
            }

            let query = typesView.createQuery();
            let result = try query.run();
            var promises: [Promise<T?>] = [];
            while let row = result.nextRow() {
                if let docId = row.documentID {
                    promises.append(load(docId))
                }
            }
            return when(promises).then(on: Recline.queue)  { results -> Void in
                //resolve([]);
                resolve(results.filter { $0 != nil}.map { $0! }  );
                }.error { err in
                    reject(err)
                }
        }

    }

    func queryAll<T: ReclineObject>() -> Promise<[T]> {
        return Promise().then(on: Recline.queue) {
            return self._queryAll()
        }
    }


    func _purge<T: ReclineObject>(obj: T) -> Promise<Bool> {
        return Promise { resolve, reject in

            var doc: CBLDocument?;
            if let rev = obj._docRevision {
                doc = rev.document;
                try doc?.purgeDocument();
                return resolve(true);
            } else {
                return resolve(true);
            }

        }
        
    }

    func purge<T: ReclineObject>(obj: T) -> Promise<Bool> {
        return Promise().then(on: Recline.queue) {
            return self._purge(obj)
        }
    }

    func compact() -> Promise<Void> {
        return Promise<Void>().then(on: Recline.queue) { _ -> Void in
            try self.db?.compact()
            }
    }

}