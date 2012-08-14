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
        unsigned int prefixLen = prefix.length();

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
    //CXSourceRange    range = clang_getCursorExtent(cursor);
    CXSourceRange    range = clang_Cursor_getSpellingNameRange(cursor, 0, 0);
    CXSourceLocation start = clang_getRangeStart(range);
    CXSourceLocation end   = clang_getRangeEnd(range);

    CXFile      file;
    unsigned    fromLine, toLine;
    unsigned    fromColumn, toColumn;

    clang_getExpansionLocation(start, &file, &fromLine, &fromColumn, 0);
    clang_getExpansionLocation(end, &file, &toLine, &toColumn, 0);

    const char *currentFilename = clang_getCString(clang_getFileName(file));

    if (!file || !data.matchesPrefix(currentFilename)) {
        return CXChildVisit_Recurse;
    }

    if (kind==CXCursor_MacroExpansion
     || kind==CXCursor_MacroInstantiation
     || kind>=500)
    {
        const auto spelling = clang_getCursorSpelling(cursor);
        std::cout << "macro: ";
        std::cout << clang_getCString(spelling);
        std::cout << std::endl;
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

        if (!clang_isCursorDefinition(cursor)) {
            CXCursor cursorDef  = clang_getCursorDefinition(cursor);
            CXCursor nullCursor = clang_getNullCursor();
            if (!clang_equalCursors(cursorDef, nullCursor)) {
                CXSourceRange    range = clang_getCursorExtent(cursorDef);

                CXSourceLocation start = clang_getRangeStart(range);

                CXFile      file;
                unsigned    line, column;

                clang_getSpellingLocation(start,
                                          &file,
                                          &line,
                                          &column,
                                          0);

                const char *dest = clang_getCString(clang_getFileName(file));

                if (file && data.matchesPrefix(dest)) {
                    std::cout << currentFilename << "@";
                    std::cout << fromLine << ":" << fromColumn << "-"
                              << toLine << ":" << toColumn
                              << "->" << dest
                              << "@" << line << "[" << kind << ":";

                    /*
                    CXSourceLocation end = clang_getRangeEnd(range);
                    clang_getExpansionLocation(end,
                                               &file,
                                               &line,
                                               &column,
                                               0);
                    std::cout << "-" << line << ":" << column << "?";
                    */

                    const auto spelling = clang_getCursorSpelling(cursor);
                    std::cout << clang_getCString(spelling);

                    /*
                    const auto display = clang_getCursorDisplayName(cursor);
                    std::cerr << clang_getCString(display) << std::endl;
                    */

                    std::cout << "]" << std::endl;
                }


            } else {
                /*
                std::cerr << currentFilename << "#"
                          << fromLine << ":" << fromColumn << "-"
                          << toLine << ":" << toColumn
                          << std::endl;
                std::cerr << "can not find definition"
                          << std::endl << std::endl;
                */
            }

        }
    } else {
        /*
        const auto spelling = clang_getCursorSpelling(cursor);
        std::cerr << currentFilename << ": skipping kind = " << kind
                  << " in lines " << fromLine << "-" << toLine
                  << clang_getCString(spelling)
                  << std::endl;
        */
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
