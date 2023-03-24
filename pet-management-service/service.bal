import ballerina/http;
import ballerina/uuid;

type PetItem record {|
    string name;
    string breed;
    string dateOfBirth;
|};

type Pet record {|
    *PetItem;
    string id;
|};

map<Pet> pets = {};

# A service representing a network-accessible API
# bound to port `9090`.
service / on new http:Listener(9090) {

    # A resource for getting the pets in the system.
    # + return - List of pets or error
    resource function get pets() returns Pet[]|error? {
        return pets.toArray();
    }

    # A resource for creating a new pet entry in the system.
    # + newPet - basic pet details
    # + return - created pet record or error
    resource function post pets(@http:Payload PetItem newPet) returns record {|*http:Created;|}|error? {
        
        string petId = uuid:createType1AsString();
        pets[petId] = {...newPet, id: petId};

        return {body:  pets[petId]};
    }

    # A resource for deleting a pet entry in the system.
    # + id - id of the pet to delete
    # + return - ok reponse or error
    resource function delete books(string id) returns record {|*http:Ok;|}|error? {
        _ = pets.remove(id);
        return {};
    }
}
