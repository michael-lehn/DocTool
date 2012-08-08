#include <cassert>
#include <cstring>
#include <iostream>
#include <string>

#include <clang-c/Index.h>

struct Data {
    std::string sourcefile;
    std::string prefix;

    Data(const char *_sourcefile, const char *_prefix)
        : sourcefile(_sourcefile), prefix(_prefix)
    {
    }

    bool
    matchesSourcefile(const char *cstr) const
    {
        return sourcefile==std::string(cstr);
    }

    bool
    matchesPrefix(const char *cstr) const
    {
        int prefixLen = prefix.length();

        if (strlen(cstr)<prefixLen) {
            return false;
        }
        if (strncmp(cstr, prefix.c_str(), prefixLen)==0) {
            return true;
        }
        return false;
    }
};

CXChildVisitResult
visitor(CXCursor cursor, CXCursor parent, CXClientData client_data)
{
    const Data &data = *static_cast<Data *>(client_data);

    CXCursorKind     kind  = clang_getCursorKind(cursor);
    //CXSourceRange  range = clang_getCursorExtent(cursor);
    CXSourceRange    range = clang_Cursor_getSpellingNameRange(cursor, 0, 0);
    CXSourceLocation start = clang_getRangeStart(range);
    CXSourceLocation end   = clang_getRangeEnd(range);

    CXFile      file;
    unsigned    fromLine=0, toLine=0;
    unsigned    fromColumn=0, toColumn=0;

    clang_getSpellingLocation(start, &file, &fromLine, &fromColumn, 0);
    clang_getSpellingLocation(end, &file, &toLine, &toColumn, 0);

    const char *currentFilename = clang_getCString(clang_getFileName(file));

    if (!file || !data.matchesPrefix(currentFilename)) {
        return CXChildVisit_Recurse;
    }

    if ((fromLine!=toLine) || (fromLine==toLine && fromColumn==toColumn)) {
        return CXChildVisit_Recurse;
    }

    if (clang_isCursorDefinition(cursor)) {
        return CXChildVisit_Recurse;
    }

    if (kind==CXCursor_Constructor
     || kind==CXCursor_Destructor
     || kind==CXCursor_CXXMethod
     || kind==CXCursor_DeclRefExpr
     || kind==CXCursor_TypeRef
     || kind==CXCursor_TemplateRef
     || kind==CXCursor_FunctionTemplate
     || kind==CXCursor_MemberRefExpr
     || kind==CXCursor_FunctionDecl)
    {

        CXCursor cursorDef  = clang_getCursorDefinition(cursor);
        CXCursor nullCursor = clang_getNullCursor();
        if (clang_equalCursors(cursorDef, nullCursor)) {
            return CXChildVisit_Recurse;
        }

        //CXSourceRange range = clang_getCursorExtent(cursorDef);
        CXSourceRange range = clang_Cursor_getSpellingNameRange(cursorDef,0,0);

        CXSourceLocation start = clang_getRangeStart(range);

        CXFile      dest_file;
        unsigned    dest_line, dest_col;

        clang_getSpellingLocation(start, &dest_file, &dest_line, &dest_col, 0);
        const char *dest = clang_getCString(clang_getFileName(dest_file));

        if (dest_file && data.matchesPrefix(dest)) {
            const auto spelling = clang_getCursorSpelling(cursor);

            std::cout << currentFilename << "@"
                      << fromLine << ":" << fromColumn << "-"
                      << toLine << ":" << toColumn
                      << "->" << dest
                      << "@" << dest_line << "[" << kind << ":"
                      << clang_getCString(spelling)
                      << "]" << std::endl;
        }
        return CXChildVisit_Recurse;
    }

    if (kind==CXCursor_OverloadedDeclRef) {
        auto spelling = clang_getCursorSpelling(cursor);
        int  n        = clang_getNumOverloadedDecls(cursor);

        std::cout << currentFilename << "@"
                  << fromLine << ":"
                  << fromColumn << "-"
                  << toLine << ":"
                  << toColumn << "=>["
                  << kind << ":"
                  << clang_getCString(spelling) << ":";

        for (int i=0; i<n; ++i) {
            auto cx    = clang_getOverloadedDecl(cursor, i);
            auto range = clang_getCursorExtent(cx);
            auto start = clang_getRangeStart(range);

            CXFile      dest_file;
            unsigned    dest_line;

            clang_getSpellingLocation(start, &dest_file, &dest_line, 0, 0);
            auto dest = clang_getCString(clang_getFileName(dest_file));

            if (dest_file) {
                if (data.matchesPrefix(dest)) {
                    std::cout << dest << "@" << dest_line;
                } else {
                    std::cout << "[external] " << dest << "@" << dest_line;
                }
            } else {
                std::cout << "[external] " << "? @" << 0;
            }
            if (i<n-1) {
                std::cout << ",";
            }
        }

        std::cout << "]" << std::endl;
        return CXChildVisit_Recurse;
    }

    return CXChildVisit_Recurse;
}


int
main(int argc, char *argv[])
{
    CXIndex      index = clang_createIndex(0, 0);

    if (argc<3) {
        std::cerr << "usage: "
                  << argv[0] << " ... sourcefile  prefix"
                  << std::endl;
        return 2;
    }

    Data  data(argv[argc-2], argv[argc-1]);

    /*
    std::cerr << "[INFO] Searching in '" << data.sourcefile
              << "' for code references defined in headers-/sourcefiles "
              << "with prefix '" << data.prefix << "'." << std::endl;
    */


    CXTranslationUnit tu = clang_parseTranslationUnit(index, argv[argc-2],
                                                      argv+1, argc-3,
                                                      0, 0,
                                                      CXTranslationUnit_None);

    unsigned n = clang_getNumDiagnostics(tu);
    if (n) {
        for (unsigned i=0, n=clang_getNumDiagnostics(tu); i!=n; ++i) {
            CXDiagnostic diag = clang_getDiagnostic(tu, i);
            auto opt = clang_defaultDiagnosticDisplayOptions();
            CXString string = clang_formatDiagnostic(diag, opt);
            std::cerr <<  clang_getCString(string) << std::endl;
            clang_disposeString(string);
        }
        return 1;
    }

    CXCursor cursor = clang_getTranslationUnitCursor(tu);

    int result = clang_visitChildren(cursor, visitor, (void *)&data);

    if (result!=0) {
        std::cerr << "clang_visitChildren(...) was interupted." << std::endl;
    }

    clang_disposeTranslationUnit(tu);
    clang_disposeIndex(index);

    std::cerr << "done." << std::endl;
    return 0;
}
