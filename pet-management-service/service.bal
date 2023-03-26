import ballerina/http;
import ballerina/uuid;
import ballerina/jwt;
import ballerina/io;

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
    resource function get pets(http:Headers headers) returns Pet[]|error? {

        string|error owner = getOwner(headers);

        if owner is error {
            return owner;
        }

        table<Pet> getPetsByOwner = from Pet pet in pets
            where pet.owner == owner
            select pet;

        return getPetsByOwner.toArray();
    }

    # Create a new pet
    # + newPet - basic pet details
    # + return - created pet record or error
    resource function post pets(http:Headers headers, @http:Payload PetItem newPet) returns record {|*http:Created;|}|error? {

        string|error owner = getOwner(headers);

        if owner is error {
            return owner;
        }

        string petId = uuid:createType1AsString();
        pets.put({id: petId, owner: owner, ...newPet});

        return {body: pets[owner, petId]};
    }

    # Get a pet by ID
    # + petId - ID of the pet
    # + return - Pet details or not found 
    resource function get pets/[string petId](http:Headers headers) returns Pet|http:NotFound|error? {

        string|error owner = getOwner(headers);

        if owner is error {
            return owner;
        }

        Pet? pet = pets[owner, petId];
        if pet is () {
            return http:NOT_FOUND;
        }
        return pet;
    }

    # Update a pet
    # + petId - ID of the pet
    # + updatedPetItem - updated pet details
    # + return - Pet details or not found 
    resource function put pets/[string petId](http:Headers headers, @http:Payload PetItem updatedPetItem) returns Pet|http:NotFound|error? {

        string|error owner = getOwner(headers);

        if owner is error {
            return owner;
        }

        Pet? pet = pets[owner, petId];
        if pet is () {
            return http:NOT_FOUND;
        }
        pets.put({id: petId, owner: owner, ...updatedPetItem});

        return pets[owner, petId];
    }

    # Delete a pet
    # + petId - ID of the pet
    # + return - Ok response or error
    resource function delete pets/[string petId](http:Headers headers) returns http:NoContent|http:NotFound|error? {

        string|error owner = getOwner(headers);

        if owner is error {
            return owner;
        }

        Pet? pet = pets[owner, petId];
        if pet is () {
            return http:NOT_FOUND;
        }
        _ = pets.remove([owner, petId]);
        return http:NO_CONTENT;
    }

    resource function post receiver(http:Request request) returns string|error {
        stream<byte[], io:Error?> streamer = check request.getByteStream();

        // Retrieve the thumbnail field from the request
        // byte[] thumbnail = check <byte[]>formData.getField("thumbnail").getBlob();
        // Writes the incoming stream to a file using the `io:fileWriteBlocksFromStream` API
        // by providing the file location to which the content should be written.
        check io:fileWriteBlocksFromStream("./files/ReceivedFile.pdf", streamer);
        check streamer.close();

        var formData = check request.getFormParams();

        var bodyParts = check request.getBodyParts();

        io:println(bodyParts);
        io:println(formData);
        return "File Received!";
    }

}

function getOwner(http:Headers headers) returns string|error {

    var jwtHeader = headers.getHeader("x-jwt-assertion");
    if jwtHeader is http:HeaderNotFoundError {
        return jwtHeader;
    }

    [jwt:Header, jwt:Payload] [_, payload] = check jwt:decode(jwtHeader);
    string? subClaim = payload.sub;

    if subClaim is () {
        subClaim = "Test_Key_User";
    }
    string owner = <string>subClaim;

    return owner;
}
