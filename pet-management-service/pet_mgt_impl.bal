
import ballerinax/java.jdbc;
// import ballerinax/mysql;
import ballerinax/mysql.driver as _;
import ballerina/io;
import ballerina/uuid;

// import ballerina/sql;

configurable string dbHost = "localhost";
configurable string dbUsername = "admin";
configurable string dbPassword = "admin123";
configurable string dbDatabase = "wso2am_db";
configurable int dbPort = 3306;
configurable boolean useDB = true;

final jdbc:Client|error dbClient;

// final mysql:Client|sql:Error dbClient;

function init() returns error? {

    jdbc:Options options = {
        properties: {
            allowPublicKeyRetrieval: true,
            user: "root",
            password: "root"
        }
    };

    dbClient = check new ("jdbc:mysql://localhost:3306/PET_DB", options = options);

    // dbClient = new ("localhostdd", "admin", "admin123", "petdb", 3306);

    // if dbClient is sql:Error {
    //     io:println("Error occured while creating the DB client", dbClient);
    //     if (!useDB) {
    //         io:println("UseDB is set to false and hence storing the data locally");
    //     } else {
    //         io:println("DB configuraitons are not correct. Please check the configuration");
    //         return error("DB configuraitons are not correct. Please check the configuration");
    //     }
    // }

    io:println("we are good");
    io:println(dbClient);

}

public function getConnection() returns jdbc:Client|error {
    return dbClient;
}

public function getPets(string owner) returns Pet[]|error {

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

public function getPetById(string owner, string petId) returns Pet|()|error {

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

public function updatePetById(string owner, string petId, PetItem updatedPetItem) returns Pet|()|error {

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

public function deletePetById(string owner, string petId) returns string|()|error {

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

public function addPet(PetItem petItem, string owner) returns Pet|error {

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

public function updateThumbnailByPetId(string owner, string petId, Thumbnail thumbnail) returns string|()|error {

    if (useDB) {

        string|()|error deleteResult = dbDeleteThumbnailById(petId);

        if deleteResult is error {
            return deleteResult;
        }

        io:println(deleteResult);

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
