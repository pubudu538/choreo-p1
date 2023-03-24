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

    # Get all pets
    # + return - List of pets or error
    resource function get pets() returns Pet[]|error? {
        return pets.toArray();
    }

    # Create a new pet
    # + newPet - basic pet details
    # + return - created pet record or error
    resource function post pets(@http:Payload PetItem newPet) returns record {|*http:Created;|}|error? {

        string petId = uuid:createType1AsString();
        pets[petId] = {...newPet, id: petId};
        return {body: pets[petId]};
    }

    # Get a pet by ID
    # + petId - ID of the pet
    # + return - Pet details or not found 
    resource function get pets/[string petId]() returns Pet|http:NotFound {

        Pet? pet = pets[petId];
        if pet is () {
            return http:NOT_FOUND;
        }
        return pet;
    }

    # Update a pet
    # + petId - ID of the pet
    # + updatedPetItem - updated pet details
    # + return - Pet details or not found 
    resource function put pets/[string petId](@http:Payload PetItem updatedPetItem) returns Pet|http:NotFound|error? {
        
        Pet? pet = pets[petId];
        if pet is () {
            return http:NOT_FOUND;
        }
        pets[petId] = {...updatedPetItem, id: petId};

        return pets[petId];
    }

    # Delete a pet
    # + petId - ID of the pet
    # + return - Ok response or error
    resource function delete pets/[string petId]() returns record {|*http:NoContent;|}|error? {

        Pet? pet = pets[petId];
        if pet is () {
            return http:NO_CONTENT;
        }
        _ = pets.remove(petId);
        return {};
    }

}
