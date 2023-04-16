import ballerinax/java.jdbc;
import ballerinax/mysql.driver as _;
import ballerina/uuid;
import ballerina/sql;
import ballerina/log;
import ballerinax/mysql;

configurable string dbHost = "localhost";
configurable string dbUsername = "admin";
configurable string dbPassword = "admin";
configurable string dbDatabase = "PET_DB";
configurable int dbPort = 3306;

table<PetRecord> key(owner, id) petRecords = table [];
table<SettingsRecord> key(owner) settingsRecords = table [];
final mysql:Client|error dbClient;
boolean useDB = false;

function init() returns error? {

    log:printInfo("DB configurations are given **** " + dbHost);

    if dbHost != "localhost" && dbHost != "" {
        useDB = true;
    }

    sql:ConnectionPool connPool = {
        maxOpenConnections: 20,
        minIdleConnections: 20,
        maxConnectionLifeTime: 300
    };

    mysql:Options mysqlOptions = {
        connectTimeout: 10
    };

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

function getPetByIdAndOwner(string owner, string petId) returns Pet|()|error {

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

function getPetById(string petId) returns Pet|() {

    if (useDB) {
        Pet|()|error petResult = dbGetPetByPetId(petId);

        if petResult is Pet {
            return petResult;
        } else {
            return ();
        }
    } else {
        string owner = from var petRecord in petRecords
            where petRecord.id == petId
            select petRecord.owner;

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

function updateSettings(SettingsRecord settingsRecord) returns string|error {

    if (useDB) {
        string|error updatedResult = dbUpdateSettingsByOwner(settingsRecord);
        if updatedResult is error {
            return updatedResult;
        }

    } else {
        settingsRecords.put(settingsRecord);
    }

    return "Settings updated successfully";
}

function getSettings(string owner, string email) returns Settings|error {

    if (useDB) {

        Settings|()|error settings = dbGetOwnerSettings(owner);

        if settings is error {
            return settings;
        } else if settings is () {
            Settings newSettings = getDefaultSettings(email);
            SettingsRecord settingsRecord = {owner: owner, ...newSettings};
            string|error updatedResult = dbUpdateSettingsByOwner(settingsRecord);
            if updatedResult is error {
                return updatedResult;
            }
            return newSettings;
        } else {
            return settings;
        }

    } else {
        SettingsRecord? settingsRecord = settingsRecords[owner];

        if settingsRecord is () {
            Settings settings = getDefaultSettings(email);
            settingsRecords.put({owner: owner, ...settings});
            return settings;
        }
        return {notifications: settingsRecord.notifications};
    }

}

function getSettingsByOwner(string owner) returns Settings|() {

    if (useDB) {

        Settings|()|error settings = dbGetOwnerSettings(owner);

        if settings is Settings {
            return settings;
        } else {
            return ();
        }

    } else {
        SettingsRecord? settingsRecord = settingsRecords[owner];

        if settingsRecord is () {
            return ();
        }

        return {notifications: settingsRecord.notifications};
    }

}

function getAvailableAlerts(string nextDay) returns PetAlert[] {

    PetAlert[] petAlerts = [];
    string[] petIds = getPetIdsForEnabledAlerts(nextDay);

    foreach var petId in petIds {
        Pet|() pet = getPetById(petId);

        if pet != () {
            Settings|() settings = getSettingsByOwner(pet.owner);

            if settings != () && settings.notifications.enabled && settings.notifications.emailAddress != "" {

                string email = <string>settings.notifications.emailAddress;
                Vaccination[] selectedVaccinations = [];
                Vaccination[] vaccinations = <Vaccination[]>pet.vaccinations;

                foreach var vac in vaccinations {
                    if vac.nextVaccinationDate == nextDay && vac.enableAlerts == true {
                        selectedVaccinations.push(vac);
                    }
                }

                pet.vaccinations = selectedVaccinations;
                PetAlert petAlert = {...pet, emailAddress: email};
                petAlerts.push(petAlert);
            }
        }
    }

    return petAlerts;
}

function getPetIdsForEnabledAlerts(string nextDay) returns string[] {

    string[] petIds = [];
    if (useDB) {
        string[]|error dbGetPetIdsForEnabledAlertsResult = dbGetPetIdsForEnabledAlerts(nextDay);

        if dbGetPetIdsForEnabledAlertsResult is error {
            return petIds;
        } else {
            return <string[]>dbGetPetIdsForEnabledAlertsResult;
        }

    } else {
        petRecords.forEach(function(PetRecord petRecord) {

            if petRecord.vaccinations is () {
                return;
            }

            Vaccination[] vaccinations = <Vaccination[]>petRecord.vaccinations;
            vaccinations.forEach(function(Vaccination vaccination) {

                if vaccination.nextVaccinationDate == nextDay && <boolean>vaccination.enableAlerts {
                    petIds.push(petRecord.id);
                }
            });
        });
    }

    return petIds;
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

function getDefaultSettings(string email) returns Settings {

    boolean enabled = false;
    if email != "" {
        enabled = true;
    }

    Settings settings = {notifications: {enabled: enabled, emailAddress: email}};
    return settings;
}
