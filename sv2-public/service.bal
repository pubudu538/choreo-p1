import ballerina/http;
import ballerina/io;

configurable string endpoint2 = "localhost:9090";

type PetItem record {|
    string name;
    string breed;
    string dateOfBirth;
    Vaccination[] vaccinations?;
|};

type Pet record {|
    *PetItem;
    readonly string id;
|};

type Thumbnail record {|
    string fileName;
    string content;
|};

type Vaccination record {|
    string name;
    string lastVaccinationDate;
    string nextVaccinationDate?;
    boolean enableAlerts?;
|};

type PetRecord record {|
    *Pet;
    readonly string owner;
    record {
        *Thumbnail;
    } thumbnail?;
|};

table<PetRecord> key(owner, id) petRecords = table [];

# A service representing a network-accessible API
# bound to port `9091`.
service / on new http:Listener(9091) {

    # Get all pets
    # + return - List of pets or error
    resource function get store(http:Headers headers) returns Pet[]|error? {

        io:println("Received request to get all pets from store");
        http:Client petClient = check new (endpoint2);

        Pet[] pets = check petClient->/pets;
        io:println("GET request:" + pets.toJsonString());

        return pets;
    }

}
