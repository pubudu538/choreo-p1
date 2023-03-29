import ballerinax/java.jdbc;
// import ballerinax/mysql;
import ballerinax/mysql.driver as _;
import ballerina/sql;
import ballerina/log;

import ballerina/io;

type PetVaccinationRecord record {|
    string id;
    string owner;
    string name;
    string breed;
    string dateOfBirth;
    string vaccinationName?;
    string lastVaccinationDate?;
    string nextVaccinationDate?;
    boolean enableAlerts?;
|};

function dbGetPetsByOwner(string owner) returns Pet[]|error {

    jdbc:Client|error dbClient = getConnection();

    if dbClient is error {
        return handleError(dbClient);
    }

    do {
        sql:ParameterizedQuery query = `SELECT p.id, p.name, p.breed, p.dateOfBirth, p.owner, v.name as vaccinationName,
        v.lastVaccinationDate, v.nextVaccinationDate, v.enableAlerts FROM Pet p LEFT JOIN Vaccination v 
        ON p.id = v.petId WHERE p.owner = ${owner}`;

        stream<PetVaccinationRecord, sql:Error?> petsStream = dbClient->query(query);

        io:println("petsStream: ", petsStream);
        map<Pet> pets = check getPetsForPetsStream(petsStream);
        check petsStream.close();
        return pets.toArray();
    }
    on fail error e {
        return handleError(e);
    }
}

function dbGetPetByOwnerAndPetId(string owner, string petId) returns Pet|()|error {

    jdbc:Client|error dbClient = getConnection();

    if dbClient is error {
        return handleError(dbClient);
    }

    do {
        sql:ParameterizedQuery query = `SELECT p.id, p.name, p.breed, p.dateOfBirth, p.owner, v.name as vaccinationName,
        v.lastVaccinationDate, v.nextVaccinationDate, v.enableAlerts FROM Pet p LEFT JOIN Vaccination v 
        ON p.id = v.petId WHERE p.owner = ${owner} and p.id = ${petId}`;

        stream<PetVaccinationRecord, sql:Error?> petsStream = dbClient->query(query);
        map<Pet> pets = check getPetsForPetsStream(petsStream);
        check petsStream.close();

        if pets.length() == 0 {
            return ();
        }
        return pets.get(petId);
    }
    on fail error e {
        return handleError(e);
    }
}

function dbDeletePetById(string owner, string petId) returns string|()|error {

    jdbc:Client|error dbClient = getConnection();

    if dbClient is error {
        return handleError(dbClient);
    }

    do {
        sql:ParameterizedQuery query = `DELETE from Pet WHERE id = ${petId} and owner = ${owner}`;
        sql:ExecutionResult|sql:Error result = dbClient->execute(query);

        if result is sql:Error {
            return handleError(result);
        } else if result is sql:ExecutionResult && result.affectedRowCount == 0 {
            return ();
        }
        return "Pet deleted successfully";
    }
    on fail error e {
        return handleError(e);
    }
}

function dbAddPet(Pet pet) returns Pet|error {

    jdbc:Client|error dbClient = getConnection();

    if dbClient is error {
        return handleError(dbClient);
    }

    transaction {

        sql:ParameterizedQuery query = `INSERT INTO Pet (id, name, breed, dateOfBirth, owner)
            VALUES (${pet.id}, ${pet.name}, ${pet.breed}, ${pet.dateOfBirth}, ${pet.owner});`;

        _ = check dbClient->execute(query);

        Vaccination[]? vacs = pet.vaccinations;
        sql:ExecutionResult[]|sql:Error batchResult = [];

        if vacs != null {

            foreach Vaccination vac in vacs {
                if vac.enableAlerts == null {
                    vac.enableAlerts = false;
                } else if (vac.nextVaccinationDate == null) {
                    vac.nextVaccinationDate = null;
                }
            }

            sql:ParameterizedQuery[] insertQueries = from Vaccination vac in vacs
                select `INSERT INTO Vaccination (petId, name, lastVaccinationDate, nextVaccinationDate,enableAlerts)
                    VALUES (${pet.id}, ${vac.name}, ${vac.lastVaccinationDate}, ${vac.nextVaccinationDate}, ${vac.enableAlerts})`;

            batchResult = dbClient->batchExecute(insertQueries);
        }

        if batchResult is sql:Error {
            rollback;
            return handleError(batchResult);
        } else {
            check commit;
            return pet;
        }

    } on fail error e {
        return handleError(e);
    }
}

function dbUpdatePet(Pet pet) returns Pet|error {

    jdbc:Client|error dbClient = getConnection();

    if dbClient is error {
        return handleError(dbClient);
    }

    transaction {

        sql:ParameterizedQuery query = `UPDATE Pet SET name = ${pet.name}, breed = ${pet.breed}, 
        dateOfBirth = ${pet.dateOfBirth} WHERE id = ${pet.id};`;

        _ = check dbClient->execute(query);

        sql:ParameterizedQuery deleteQuery = `DELETE FROM Vaccination WHERE petId = ${pet.id};`;
        _ = check dbClient->execute(deleteQuery);

        Vaccination[]? vacs = pet.vaccinations;
        sql:ExecutionResult[]|sql:Error batchResult = [];

        if vacs != null {

            foreach Vaccination vac in vacs {
                if vac.enableAlerts == null {
                    vac.enableAlerts = false;
                } else if (vac.nextVaccinationDate == null) {
                    vac.nextVaccinationDate = null;
                }
            }

            sql:ParameterizedQuery[] insertQueries = from Vaccination vac in vacs
                select `INSERT INTO Vaccination (petId, name, lastVaccinationDate, nextVaccinationDate,enableAlerts)
                    VALUES (${pet.id}, ${vac.name}, ${vac.lastVaccinationDate}, ${vac.nextVaccinationDate}, ${vac.enableAlerts})`;

            batchResult = dbClient->batchExecute(insertQueries);
        }

        if batchResult is sql:Error {
            rollback;
            return handleError(batchResult);
        } else {
            check commit;
            return pet;
        }

    } on fail error e {
        return handleError(e);
    }
}

function dbAddThumbnailById(string petId, Thumbnail thumbnail) returns string|error {

    jdbc:Client|error dbClient = getConnection();

    if dbClient is error {
        return handleError(dbClient);
    }

    do {
        sql:ParameterizedQuery query = `INSERT INTO Thumbnail (petId, fileName, content)
            VALUES (${petId}, ${thumbnail.fileName}, ${thumbnail.content.toBytes()});`;

        _ = check dbClient->execute(query);

        return "Thumbnail added successfully";
    }
    on fail error e {
        return handleError(e);
    }

}

function dbDeleteThumbnailById(string petId) returns string|()|error {

    jdbc:Client|error dbClient = getConnection();

    if dbClient is error {
        return handleError(dbClient);
    }

    do {
        sql:ParameterizedQuery query = `DELETE FROM Thumbnail WHERE petId = ${petId};`;
        sql:ExecutionResult|sql:Error result = check dbClient->execute(query);

        io:println(result);
        if result is sql:Error {
            return handleError(result);
        } else if result is sql:ExecutionResult && result.affectedRowCount == 0 {
            return ();
        }
        return "Thumbnail deleted successfully";
    }
    on fail error e {
        return handleError(e);
    }

}

function handleError(error err) returns error {
    log:printError("Error while processing the request", err);
    return error("Error while processing the request");
}

function getPetsForPetsStream(stream<PetVaccinationRecord, sql:Error?> petsStream) returns map<Pet>|error {

    map<Pet> pets = {};

    check from PetVaccinationRecord pet in petsStream
        do {
            boolean isPetAvailable = pets.hasKey(pet.id);
            io:println(pet);
            io:println(pet.vaccinationName);
            io:println(pet.lastVaccinationDate);
            io:println(pet.nextVaccinationDate);
            io:println(pet.enableAlerts);
            if !isPetAvailable {

                Pet p = {
                    id: pet.id,
                    owner: pet.owner,
                    name: pet.name,
                    breed: pet.breed,
                    dateOfBirth: pet.dateOfBirth
                };

                if (pet.vaccinationName != null) {
                    Vaccination[] vacs = [
                        {
                            name: <string>pet.vaccinationName,
                            lastVaccinationDate: <string>pet.lastVaccinationDate,
                            nextVaccinationDate: pet.nextVaccinationDate,
                            enableAlerts: pet.enableAlerts
                        }
                    ];
                    p.vaccinations = vacs;
                }

                pets[pet.id] = p;
            } else {

                if (pet.vaccinationName != null) {
                    Vaccination vac = {
                        name: pet.vaccinationName ?: "",
                        lastVaccinationDate: pet.lastVaccinationDate ?: "",
                        nextVaccinationDate: pet.nextVaccinationDate,
                        enableAlerts: pet.enableAlerts
                    };

                    Pet p = pets.get(pet.id);
                    Vaccination[] vacarray = <Vaccination[]>p.vaccinations;
                    vacarray.push(vac);
                }
            }
        };

    return pets;
}