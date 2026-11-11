import EhModels
import EhNetworking
import Foundation
import Testing

private typealias T = RequestTesting

@Suite struct GalleryOperationRequestTests {
    private let galleryURL = T.url("https://exhentai.org/g/2345678/0a1b2c3d4e/")

    @Test(arguments: GalleryHost.allCases)
    func favor(host: GalleryHost) {
        T.expectFormPOST(
            T.builder(host).favorGallery(gid: "2345678", token: "0a1b2c3d4e", favIndex: 3),
            T.origin(host) + "/gallerypopups.php?gid=2345678&t=0a1b2c3d4e&act=addfav",
            body: "favcat=3&favnote=&apply=Add%20to%20Favorites&update=1"
        )
    }

    @Test(arguments: GalleryHost.allCases)
    func unfavor(host: GalleryHost) {
        T.expectFormPOST(
            T.builder(host).unfavorGallery(gid: "2345678"),
            T.origin(host) + "/favorites.php",
            body: "ddact=delete&modifygids%5B%5D=2345678&apply=Apply"
        )
    }

    @Test func downloadCommandPostsToTheArchiveURL() {
        T.expectFormPOST(
            T.eh.sendDownloadCommand(
                archiveURL: T.url("https://exhentai.org/archiver.php?gid=2345678&token=0a1b2c3d4e"),
                resolution: "1280x"
            ),
            "https://exhentai.org/archiver.php?gid=2345678&token=0a1b2c3d4e",
            body: "hathdl_xres=1280x"
        )
    }

    @Test(arguments: GalleryHost.allCases)
    func rate(host: GalleryHost) throws {
        let request = T.builder(host).rateGallery(
            apiuid: 1234567, apikey: "abcdef0123", gid: 2345678, token: "0a1b2c3d4e", rating: 7
        )
        T.expectJSONPOST(
            request, T.origin(host) + "/api.php",
            body: #"{"apikey":"abcdef0123","apiuid":1234567,"gid":2345678,"method":"rategallery","#
                + #""rating":7,"token":"0a1b2c3d4e"}"#
        )
        let json = try T.json(request)
        #expect(json["apiuid"] as? Int == 1234567)
        #expect(json["rating"] as? Int == 7)
    }

    @Test func commentPostsToTheGalleryURL() {
        T.expectFormPOST(
            T.eh.commentGallery(content: "Nice", galleryURL: galleryURL),
            "https://exhentai.org/g/2345678/0a1b2c3d4e/",
            body: "commenttext_new=Nice"
        )
    }

    @Test func commentNewlinesAreEscapedTwiceAsInLegacy() {
        // "\n" becomes "%0A", whose "%" the form encoding then escapes again.
        T.expectFormPOST(
            T.eh.commentGallery(content: "line one\nline two", galleryURL: galleryURL),
            "https://exhentai.org/g/2345678/0a1b2c3d4e/",
            body: "commenttext_new=line%20one%250Aline%20two"
        )
    }

    @Test func commentEscapesFormSeparators() {
        T.expectFormPOST(
            T.eh.commentGallery(content: "a&b=c+d 中", galleryURL: galleryURL),
            "https://exhentai.org/g/2345678/0a1b2c3d4e/",
            body: "commenttext_new=a%26b%3Dc%2Bd%20%E4%B8%AD"
        )
    }

    @Test func editComment() {
        T.expectFormPOST(
            T.ex.editGalleryComment(commentID: "4567890", content: "fixed\ntext", galleryURL: galleryURL),
            "https://exhentai.org/g/2345678/0a1b2c3d4e/",
            body: "edit_comment=4567890&commenttext_edit=fixed%250Atext"
        )
    }

    @Test(arguments: GalleryHost.allCases)
    func voteComment(host: GalleryHost) {
        T.expectJSONPOST(
            T.builder(host).voteGalleryComment(
                apiuid: 1234567, apikey: "abcdef0123", gid: 2345678, token: "0a1b2c3d4e",
                commentID: 4567890, commentVote: -1
            ),
            T.origin(host) + "/api.php",
            body: #"{"apikey":"abcdef0123","apiuid":1234567,"comment_id":4567890,"comment_vote":-1,"#
                + #""gid":2345678,"method":"votecomment","token":"0a1b2c3d4e"}"#
        )
    }

    @Test(arguments: GalleryHost.allCases)
    func voteTag(host: GalleryHost) {
        T.expectJSONPOST(
            T.builder(host).voteGalleryTag(
                apiuid: 1234567, apikey: "abcdef0123", gid: 2345678, token: "0a1b2c3d4e",
                tag: "female:big breasts", vote: 1
            ),
            T.origin(host) + "/api.php",
            body: #"{"apikey":"abcdef0123","apiuid":1234567,"gid":2345678,"method":"taggallery","#
                + #""tags":"female:big breasts","token":"0a1b2c3d4e","vote":1}"#
        )
    }
}
