import ballerina/http;
import ballerina/jwt;
import ballerina/mime;

# A service representing a network-accessible API
# bound to port `9090`.
service / on new http:Listener(9090) {

    # Get all pets
    # + return - List of pets or error
    resource function get pets(@http:Header string x\-jwt\-assertion) returns Pet[]|error? {

        string|error owner = getOwner(x\-jwt\-assertion);
        if owner is error {
            return owner;
        }

        return getPets(owner);
    }

    # Create a new pet
    # + newPet - basic pet details
    # + return - created pet record or error
    resource function post pets(@http:Header string x\-jwt\-assertion, @http:Payload PetItem newPet) returns Pet|http:Created|error? {

        string|error owner = getOwner(x\-jwt\-assertion);
        if owner is error {
            return owner;
        }

        Pet|error pet = addPet(newPet, owner);
        return pet;
    }

    # Get a pet by ID
    # + petId - ID of the pet
    # + return - Pet details or not found 
    resource function get pets/[string petId](@http:Header string x\-jwt\-assertion) returns Pet|http:NotFound|error? {

        string|error owner = getOwner(x\-jwt\-assertion);
        if owner is error {
            return owner;
        }

        Pet|()|error result = getPetById(owner, petId);
        if result is () {
            return http:NOT_FOUND;
        }
        return result;
    }

    # Update a pet
    # + petId - ID of the pet
    # + updatedPetItem - updated pet details
    # + return - Pet details or not found 
    resource function put pets/[string petId](@http:Header string x\-jwt\-assertion, @http:Payload PetItem updatedPetItem) returns Pet|http:NotFound|error? {

        string|error owner = getOwner(x\-jwt\-assertion);
        if owner is error {
            return owner;
        }

        Pet|()|error result = updatePetById(owner, petId, updatedPetItem);
        if result is () {
            return http:NOT_FOUND;
        }
        return result;
    }

    # Delete a pet
    # + petId - ID of the pet
    # + return - Ok response or error
    resource function delete pets/[string petId](@http:Header string x\-jwt\-assertion) returns http:NoContent|http:NotFound|error? {

        string|error owner = getOwner(x\-jwt\-assertion);
        if owner is error {
            return owner;
        }

        string|()|error result = deletePetById(owner, petId);
        if result is () {
            return http:NOT_FOUND;
        } else if result is error {
            return result;
        }
        return http:NO_CONTENT;
    }

    resource function put pets/[string petId]/thumbnail(http:Request request, @http:Header string x\-jwt\-assertion)
    returns http:Ok|http:NotFound|http:BadRequest|error {

        string|error owner = getOwner(x\-jwt\-assertion);
        if owner is error {
            return owner;
        }

        var bodyParts = check request.getBodyParts();
        Thumbnail thumbnail;
        if bodyParts.length() == 0 {
            thumbnail = {fileName: "", content: ""};
        } else {
            Thumbnail|error? handleContentResult = handleContent(bodyParts[0]);
            if handleContentResult is error {
                return http:BAD_REQUEST;
            }
            thumbnail = <Thumbnail>handleContentResult;
        }

        string|()|error thumbnailByPetId = updateThumbnailByPetId(owner, petId, thumbnail);

        if thumbnailByPetId is error {
            return thumbnailByPetId;
        } else if thumbnailByPetId is () {
            return http:NOT_FOUND;
        }

        return http:OK;
    }

    resource function get pets/[string petId]/thumbnail(@http:Header string x\-jwt\-assertion) returns http:Response|http:NotFound|error {

        string|error owner = getOwner(x\-jwt\-assertion);
        if owner is error {
            return owner;
        }

        Thumbnail|()|string|error thumbnail = getThumbnailByPetId(owner, petId);
        http:Response response = new;

        if thumbnail is () {
            return http:NOT_FOUND;
        } else if thumbnail is error {
            return thumbnail;
        } else if thumbnail is string {
            return response;
        } else if thumbnail is Thumbnail {

            string fileName = thumbnail.fileName;
            byte[] encodedContent = thumbnail.content.toBytes();
            byte[] base64Decoded = <byte[]>(check mime:base64Decode(encodedContent));

            response.setHeader("Content-Type", "application/octet-stream");
            response.setHeader("Content-Disposition", "attachment; filename=" + fileName);
            response.setBinaryPayload(base64Decoded);
        }

        return response;
    }

}

function getOwner(@http:Header string x\-jwt\-assertion) returns string|error {

    [jwt:Header, jwt:Payload] [_, payload] = check jwt:decode(x\-jwt\-assertion);
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

