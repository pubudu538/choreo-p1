import ballerina/http;
import ballerina/uuid;
import ballerina/jwt;
import ballerina/mime;
import ballerina/io;

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
# bound to port `9090`.
service / on new http:Listener(9090) {

    # Get all pets
    # + return - List of pets or error
    resource function get pets(http:Headers headers) returns Pet[]|error? {

        // string|error owner = getOwner(headers);
        // if owner is error {
        //     return owner;
        // }
        io:println("Received request to get all pets");
        Pet[] pets = [];

        Pet pet = {
            id: "1",
            name: "Tommy",
            breed: "Pug",
            dateOfBirth: "2019-02-13",
            vaccinations: [
                {
                    name: "Rabies",
                    lastVaccinationDate: "2019-02-13",
                    nextVaccinationDate: "2020-02-13",
                    enableAlerts: true
                },
                {
                    name: "Distemper",
                    lastVaccinationDate: "2019-02-13",
                    nextVaccinationDate: "2020-02-13",
                    enableAlerts: true
                }
            ]
        };

        pets.push(pet);

        // Pet[] filteredPets = [];
        // petRecords.forEach(function(PetRecord petRecord) {

        //     if petRecord.owner == owner {
        //         Pet pet = getPetDetails(petRecord);
        //         filteredPets.push(pet);
        //     }

        // });

        return pets;
    }

    # Create a new pet
    # + newPet - basic pet details
    # + return - created pet record or error
    resource function post pets(http:Headers headers, @http:Payload PetItem newPet) returns Pet|http:Created|error? {

        string|error owner = getOwner(headers);

        if owner is error {
            return owner;
        }

        string petId = uuid:createType1AsString();
        petRecords.put({id: petId, owner: owner, ...newPet});

        PetRecord petRecord = <PetRecord>petRecords[owner, petId];
        Pet pet = getPetDetails(petRecord);

        return pet;
    }

    # Get a pet by ID
    # + petId - ID of the pet
    # + return - Pet details or not found 
    resource function get pets/[string petId](http:Headers headers) returns Pet|http:NotFound|error? {

        string|error owner = getOwner(headers);

        if owner is error {
            return owner;
        }

        PetRecord? petRecord = petRecords[owner, petId];
        if petRecord is () {
            return http:NOT_FOUND;
        }

        Pet pet = getPetDetails(petRecord);
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

        PetRecord? oldePetRecord = petRecords[owner, petId];
        if oldePetRecord is () {
            return http:NOT_FOUND;
        }
        petRecords.put({id: petId, owner: owner, ...updatedPetItem});

        PetRecord petRecord = <PetRecord>petRecords[owner, petId];
        Pet pet = getPetDetails(petRecord);

        return pet;
    }

    # Delete a pet
    # + petId - ID of the pet
    # + return - Ok response or error
    resource function delete pets/[string petId](http:Headers headers) returns http:NoContent|http:NotFound|error? {

        string|error owner = getOwner(headers);

        if owner is error {
            return owner;
        }

        PetRecord? oldePetRecord = petRecords[owner, petId];
        if oldePetRecord is () {
            return http:NOT_FOUND;
        }
        _ = petRecords.remove([owner, petId]);
        return http:NO_CONTENT;
    }

    resource function put pets/[string petId]/thumbnail(http:Request request, http:Headers headers)
    returns http:Ok|http:NotFound|http:BadRequest|error {

        string|error owner = getOwner(headers);

        if owner is error {
            return owner;
        }

        var bodyParts = check request.getBodyParts();
        foreach var part in bodyParts {

            Thumbnail|error? handleContentResult = handleContent(part);
            if handleContentResult is error {
                return http:BAD_REQUEST;
            }

            PetRecord? petRecord = petRecords[owner, petId];
            if petRecord is () {
                return http:NOT_FOUND;
            }

            petRecord.thumbnail = handleContentResult;
            petRecords.put(petRecord);
        }

        return http:OK;
    }

    resource function get pets/[string petId]/thumbnail(http:Headers headers) returns http:Response|http:NotFound|error {

        string|error owner = getOwner(headers);

        if owner is error {
            return owner;
        }

        PetRecord? petRecord = petRecords[owner, petId];
        if petRecord is () {
            return http:NOT_FOUND;
        }

        http:Response response = new;
        if petRecord.thumbnail is () {
            return response;
        }

        Thumbnail thumbnail = <Thumbnail>petRecord.thumbnail;
        string fileName = thumbnail.fileName;

        byte[] encodedContent = thumbnail.content.toBytes();
        byte[] base64Decoded = <byte[]>(check mime:base64Decode(encodedContent));

        response.setHeader("Content-Type", "application/octet-stream");
        response.setHeader("Content-Disposition", "attachment; filename=" + fileName);
        response.setBinaryPayload(base64Decoded);

        return response;
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

function handleContent(mime:Entity bodyPart) returns Thumbnail|error? {

    var mediaType = mime:getMediaType(bodyPart.getContentType());
    mime:ContentDisposition contentDisposition = bodyPart.getContentDisposition();
    string fileName = contentDisposition.fileName;

    if mediaType is mime:MediaType {

        string baseType = mediaType.getBaseType();
        if mime:IMAGE_JPEG == baseType || mime:IMAGE_GIF == baseType || mime:IMAGE_PNG == baseType {

            byte[] bytes = check bodyPart.getByteArray();
            byte[] base64Encoded = <byte[]>(check mime:base64Encode(bytes));
            string base64EncodedString = check string:fromBytes(base64Encoded);

            Thumbnail thumbnail = {
                fileName: fileName,
                content: base64EncodedString
            };

            return thumbnail;
        }
    }

    return error("Unsupported media type found");
}

function getPetDetails(PetRecord petRecord) returns Pet {

    Pet pet = {
        id: petRecord.id,
        name: petRecord.name,
        breed: petRecord.breed,
        dateOfBirth: petRecord.dateOfBirth,
        vaccinations: petRecord.vaccinations
    };

    return pet;
}
