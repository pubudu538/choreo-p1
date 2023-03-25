import ballerina/http;
import ballerina/io;
import ballerina/uuid;

type PetItem record {|
    string name;
    string breed;
    string dateOfBirth;
|};

type Pet record {|
    *PetItem;
    readonly string id;
    readonly string owner;
|};

table<Pet> key(owner, id) pets = table [];

# A service representing a network-accessible API
# bound to port `9090`.
service / on new http:Listener(9090) {

    # Get all pets
    # + return - List of pets or error
    resource function get pets(http:Request request) returns Pet[]|error? {

        table<Pet> highPaidEmployees = from Pet pet in pets
            where pet.owner == "John"
            select pet;

        return highPaidEmployees.toArray();
    }

    # Create a new pet
    # + newPet - basic pet details
    # + return - created pet record or error
    resource function post pets(@http:Payload PetItem newPet, http:Request request) returns record {|*http:Created;|}|error? {

        var jwt = request.getHeader("x-jwt-assertion");

        if (jwt is string) {
            io:println("JWT: " + jwt);
        }
        string petId = uuid:createType1AsString();
        pets.put({id: petId, owner: "John", ...newPet});

        return {body: pets["John", petId]};
    }

    # Get a pet by ID
    # + petId - ID of the pet
    # + return - Pet details or not found 
    resource function get pets/[string petId]() returns Pet|http:NotFound {

        Pet? pet = pets["John", petId];
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

        Pet? pet = pets["John", petId];
        if pet is () {
            return http:NOT_FOUND;
        }
        pets.put({id: petId, owner: "John", ...updatedPetItem});

        return pets["John", petId];
    }

    # Delete a pet
    # + petId - ID of the pet
    # + return - Ok response or error
    resource function delete pets/[string petId]() returns http:NoContent|http:NotFound|error? {

        Pet? pet = pets["John", petId];
        if pet is () {
            return http:NOT_FOUND;
        }
        _ = pets.remove(["John", petId]);
        return http:NO_CONTENT;
    }

}
