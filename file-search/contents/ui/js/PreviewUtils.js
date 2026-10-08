.import "utils.js" as Utils

var IMAGE_EXTENSIONS = ["png", "jpg", "jpeg", "gif", "bmp", "webp", "svg", "ico", "tiff"];
var VIDEO_EXTENSIONS = ["mp4", "mkv", "avi", "webm", "mov", "flv", "wmv", "mpg", "mpeg", "m4v"];
var TEXT_EXTENSIONS = ["txt", "md", "log", "ini", "cfg", "conf", "json", "xml", "yml", "yaml", "qml", "js", "ts", "py", "cpp", "c", "cc", "h", "hpp", "sh"];
var DOCUMENT_EXTENSIONS = ["pdf", "odt", "doc", "docx", "ppt", "pptx", "xls", "xlsx", "ods", "odp", "csv", "cbz", "epub"];
var APPLICATION_EXTENSIONS = ["desktop"];

function normalizeSettings(settings) {
    return {
        images: !!(settings && settings.images),
        videos: !!(settings && settings.videos),
        text: !!(settings && settings.text),
        documents: !!(settings && settings.documents),
        applications: !!(settings && settings.applications)
    };
}

function toStringValue(value) {
    if (value === undefined || value === null)
        return "";
    return value.toString ? value.toString() : String(value);
}

function hasControlCharacters(value) {
    return /[\x00-\x1f\x7f]/.test(value);
}

function isLocalFileUrl(urlOrPath) {
    var value = toStringValue(urlOrPath);
    if (value.indexOf("/") === 0)
        return !hasControlCharacters(value);
    if (value.indexOf("file:///") === 0 || value.indexOf("file://localhost/") === 0)
        return !hasControlCharacters(value);
    return false;
}

function getLocalPreviewPath(urlOrPath) {
    var value = toStringValue(urlOrPath);
    if (!isLocalFileUrl(value))
        return "";

    if (value.indexOf("file://localhost/") === 0)
        value = value.substring("file://localhost".length);
    else if (value.indexOf("file:///") === 0)
        value = value.substring("file://".length);
    else
        return value;

    try {
        value = decodeURIComponent(value);
    } catch (e) {
        return "";
    }
    return hasControlCharacters(value) || value.indexOf("/") !== 0 ? "" : value;
}

function encodeLocalPath(path) {
    return path.split("/").map(function (segment) {
        return encodeURIComponent(segment);
    }).join("/");
}

function toLocalFileUrl(urlOrPath) {
    var path = getLocalPreviewPath(urlOrPath);
    if (!path)
        return "";
    return "file://" + encodeLocalPath(path);
}

function getExtension(pathOrUrl) {
    var path = getLocalPreviewPath(pathOrUrl);
    if (!path)
        return "";

    var lastSlash = path.lastIndexOf("/");
    var lastDot = path.lastIndexOf(".");
    if (lastDot <= lastSlash + 1)
        return "";

    return path.substring(lastDot + 1).toLowerCase();
}

function containsExt(list, ext) {
    return list.indexOf(ext) !== -1;
}

function isImageExtension(ext) {
    return containsExt(IMAGE_EXTENSIONS, ext);
}

function isVideoExtension(ext) {
    return containsExt(VIDEO_EXTENSIONS, ext);
}

function isTextExtension(ext) {
    return containsExt(TEXT_EXTENSIONS, ext);
}

function isDocumentExtension(ext) {
    return containsExt(DOCUMENT_EXTENSIONS, ext);
}

function isDocumentLikeExtension(ext) {
    return isDocumentExtension(ext) || isTextExtension(ext);
}

function isPreviewTypeEnabled(ext, settings) {
    var normalized = normalizeSettings(settings);
    if (!ext)
        return false;
    if (isImageExtension(ext))
        return normalized.images;
    if (isVideoExtension(ext))
        return normalized.videos;
    if (isTextExtension(ext))
        return normalized.text;
    if (isDocumentExtension(ext))
        return normalized.documents;
    if (containsExt(APPLICATION_EXTENSIONS, ext))
        return normalized.applications;
    return false;
}

function isPreviewAvailable(urlOrPath, category, settings) {
    var path = getLocalPreviewPath(urlOrPath);
    var isApplication = Utils.isAppCategory(category, urlOrPath, "", "");
    if (!path && !isApplication)
        return false;

    var ext = getExtension(path);
    if (isApplication || ext === "desktop")
        return !!(settings && settings.applications);
    return isPreviewTypeEnabled(ext, settings);
}

function getThumbnailCacheSource(urlOrPath, thumbnailCacheBase) {
    var uri = toLocalFileUrl(urlOrPath);
    var base = getLocalPreviewPath(thumbnailCacheBase);
    if (!uri || !base)
        return "";
    if (base.charAt(base.length - 1) === "/")
        base = base.substring(0, base.length - 1);
    return toLocalFileUrl(base + "/normal/" + Qt.md5(uri) + ".png");
}

function getPreviewSource(urlOrPath, previewEnabled, settings, thumbnailCacheBase, category) {
    if (!previewEnabled)
        return "";

    var path = getLocalPreviewPath(urlOrPath);
    if (!path)
        return "";

    var ext = getExtension(path);
    if (!isPreviewAvailable(path, category || "", settings))
        return "";

    if (isImageExtension(ext))
        return toLocalFileUrl(path);

    if (isVideoExtension(ext) || isDocumentExtension(ext))
        return getThumbnailCacheSource(path, thumbnailCacheBase);

    return "";
}

function getFileTypeLabel(urlOrPath) {
    var ext = getExtension(urlOrPath);
    return ext ? ext.toUpperCase() : "";
}
