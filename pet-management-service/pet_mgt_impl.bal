import ballerinax/java.jdbc;
import ballerinax/mysql.driver as _;
import ballerina/uuid;
import ballerina/sql;
import ballerina/log;
import ballerinax/mysql;
import ballerina/io;

configurable string dbHost = "localhost";
configurable string dbUsername = "admin";
configurable string dbPassword = "admin";
configurable string dbDatabase = "PET_DB";
configurable int dbPort = 3306;

table<PetRecord> key(owner, id) petRecords = table [];
// final jdbc:Client|error dbClient;
final mysql:Client|error dbClient;

boolean useDB = false;

function init() returns error? {

    if dbHost != "localhost" {
        useDB = true;
    }

    sql:ConnectionPool connPool = {
        maxOpenConnections: 20,
        minIdleConnections: 20,
        maxConnectionLifeTime: 0
    };

    // jdbc:Options options = {
    //     properties: {
    //         autoReconnect: true,
    //         maxReconnects: 10,
    //         validationQuery: "SELECT 1",
    //         testOnBorrow: true
    //     }
    // };

    mysql:Options mysqlOptions = {
        connectTimeout: 10
    };

    // dbClient = new ("jdbc:mysql://" + dbHost + ":" + dbPort.toString() + "/" + dbDatabase, dbUsername, dbPassword, options = options,
    // connectionPool = connPool);

    dbClient = new (dbHost, dbUsername, dbPassword, dbDatabase, dbPort, options = mysqlOptions, connectionPool = connPool);

    if dbClient is sql:Error {
        if (!useDB) {
            log:printInfo("DB configurations are not given. Hence storing the data locally");
        } else {
            log:printError("DB configuraitons are not correct. Please check the configuration", 'error = <sql:Error>dbClient);
            return error("DB configuraitons are not correct. Please check the configuration");
        }
    }

    if useDB {
        log:printInfo("DB configurations are given. Hence storing the data in DB");
    }

}

function getConnection() returns jdbc:Client|error {
    io:println("DB client new connection - ", dbClient);
    return dbClient;
}

function getPets(string owner) returns Pet[]|error {

    Pet[] pets = [];
    if (useDB) {
        pets = check dbGetPetsByOwner(owner);
    } else {
        petRecords.forEach(function(PetRecord petRecord) {

            if petRecord.owner == owner {
                Pet pet = getPetDetails(petRecord);
                pets.push(pet);
            }
        });
    }
    return pets;
}

function getPetById(string owner, string petId) returns Pet|()|error {

    if (useDB) {
        return dbGetPetByOwnerAndPetId(owner, petId);
    } else {
        PetRecord? petRecord = petRecords[owner, petId];
        if petRecord is () {
            return ();
        }
        return getPetDetails(petRecord);
    }
}

function updatePetById(string owner, string petId, PetItem updatedPetItem) returns Pet|()|error {

    if (useDB) {
        Pet|() oldPet = check dbGetPetByOwnerAndPetId(owner, petId);
        if oldPet is () {
            return ();
        }

        Pet pet = {id: petId, owner: owner, ...updatedPetItem};
        return dbUpdatePet(pet);
    } else {
        PetRecord? oldePetRecord = petRecords[owner, petId];
        if oldePetRecord is () {
            return ();
        }
        petRecords.put({id: petId, owner: owner, ...updatedPetItem});
        PetRecord petRecord = <PetRecord>petRecords[owner, petId];
        return getPetDetails(petRecord);
    }
}

function deletePetById(string owner, string petId) returns string|()|error {

    if (useDB) {
        return dbDeletePetById(owner, petId);
    } else {
        PetRecord? oldePetRecord = petRecords[owner, petId];
        if oldePetRecord is () {
            return ();
        }
        _ = petRecords.remove([owner, petId]);
        return "Pet deleted successfully";
    }
}

function addPet(PetItem petItem, string owner) returns Pet|error {

    string petId = uuid:createType1AsString();

    if (useDB) {
        Pet pet = {id: petId, owner: owner, ...petItem};
        Pet addedPet = check dbAddPet(pet);
        return addedPet;
    } else {
        petRecords.put({id: petId, owner: owner, ...petItem});
        PetRecord petRecord = <PetRecord>petRecords[owner, petId];
        return getPetDetails(petRecord);
    }
}

function updateThumbnailByPetId(string owner, string petId, Thumbnail thumbnail) returns string|()|error {

    if (useDB) {

        string|()|error deleteResult = dbDeleteThumbnailById(petId);

        if deleteResult is error {
            return deleteResult;
        }

        if thumbnail.fileName != "" {
            string|error result = dbAddThumbnailById(petId, thumbnail);

            if result is error {
                return result;
            }
        }

        return "Thumbnail updated successfully";
    } else {

        PetRecord? petRecord = petRecords[owner, petId];
        if petRecord is () {
            return ();
        }

        if thumbnail.fileName == "" {
            petRecord.thumbnail = ();
            petRecords.put(petRecord);

        } else {
            petRecord.thumbnail = thumbnail;
            petRecords.put(petRecord);

        }
        return "Thumbnail updated successfully";
    }
}

function getThumbnailByPetId(string owner, string petId) returns Thumbnail|()|string|error {

    if (useDB) {

        Thumbnail|string|error getResult = dbGetThumbnailById(petId);

        if getResult is error {
            return getResult;
        } else if getResult is string {
            return getResult;
        } else {
            return <Thumbnail>getResult;
        }

    } else {

        PetRecord? petRecord = petRecords[owner, petId];
        if petRecord is () {
            return ();
        }

        Thumbnail? thumbnail = <Thumbnail?>petRecord.thumbnail;
        if thumbnail is () {
            return "No thumbnail found";
        }
        return <Thumbnail>thumbnail;
    }
}

function getPetDetails(PetRecord petRecord) returns Pet {

    Pet pet = {
        id: petRecord.id,
        owner: petRecord.owner,
        name: petRecord.name,
        breed: petRecord.breed,
        dateOfBirth: petRecord.dateOfBirth,
        vaccinations: petRecord.vaccinations
    };

    return pet;
}
