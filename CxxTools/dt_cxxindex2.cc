/*

   Call with

   ./dt_cxxindex2 -x c++ -std=c++11 -Wall -I$PWD $PWD/func.cc


   Compile with

   clang++ -std=c++11 -stdlib=libc++ -Wall \
           -I /opt/local/libexec/llvm-3.1/include/ \
           -lclang -o dt_cxxindex dt_cxxindex2.cc
 */




#include <cassert>
#include <cstring>
#include <iostream>
#include <string>

#include <clang-c/Index.h>

using namespace std;

struct Data {
    string sourcefile;
    string headerfile;

    Data(const char *_sourcefile)
        : sourcefile(_sourcefile),
          headerfile(sourcefile.substr(0, sourcefile.find(".")) + ".h")
    {
    }

    bool
    matchesHeaderfile(const char *cstr) const
    {
        return headerfile==string(cstr);
    }

    bool
    matchesSourcefile(const char *cstr) const
    {
        return sourcefile==string(cstr);
    }
};


CXChildVisitResult
visitor(CXCursor cursor, CXCursor parent, CXClientData client_data)
{
    const Data &data = *static_cast<Data *>(client_data);

    CXCursorKind     kind  = clang_getCursorKind(cursor);
    CXSourceRange    range = clang_getCursorExtent(cursor);
    CXSourceLocation start = clang_getRangeStart(range);
    CXSourceLocation end   = clang_getRangeEnd(range);

    CXFile      file;
    unsigned    fromLine, toLine;
    unsigned    fromColumn, toColumn;

    clang_getExpansionLocation(start, &file, &fromLine, &fromColumn, 0);
    clang_getExpansionLocation(end, &file, &toLine, &toColumn, 0);

    const char *currentFilename = clang_getCString(clang_getFileName(file));

    if (!file || !data.matchesHeaderfile(currentFilename)) {
        return CXChildVisit_Recurse;
    }

    std::cout << "kind = " << kind
              << ", name = " << clang_getCString(clang_getCursorSpelling(cursor))
              << std::endl;
    if (kind==CXCursor_FunctionTemplate) {
        auto result = clang_getCursorResultType(cursor);
        std::cout << ", result.kind = " << result.kind << std::endl;
    }

    if (kind==CXCursor_Namespace) {
        const auto spelling = clang_getCursorSpelling(cursor);
        cout << currentFilename << "@";

        CXFile              file;
        unsigned            line, column;

        CXCursor            cursorDef = clang_getCursorDefinition(cursor);
        CXSourceRange       range = clang_getCursorExtent(cursorDef);

        CXSourceLocation    start = clang_getRangeStart(range);
        clang_getExpansionLocation(start,
                                   &file,
                                   &line,
                                   &column,
                                   0);

        cout << line << ":" << column << "-";

        CXSourceLocation    end = clang_getRangeEnd(range);
        clang_getExpansionLocation(end,
                                   &file,
                                   &line,
                                   &column,
                                   0);

        cout << line << ":" << column;
        cout << "#namespace:" << clang_getCString(spelling);

        const auto display = clang_getCursorUSR(cursor);
        std::cout << "," << clang_getCString(display);
        cout << endl;

    }

    if (kind==CXCursor_ClassDecl
     || kind==CXCursor_StructDecl
     || kind==CXCursor_ClassTemplate)
    {
        if (clang_isCursorDefinition(cursor)) {

            cout << currentFilename << "@";

            CXFile              file;
            unsigned            line, column;
            CXCursor            cursorDef = clang_getCursorDefinition(cursor);
            CXSourceRange       range = clang_getCursorExtent(cursorDef);

            CXSourceLocation    start = clang_getRangeStart(range);
            clang_getExpansionLocation(start,
                                       &file,
                                       &line,
                                       &column,
                                       0);

            cout << line << ":" << column << "-";

            CXSourceLocation    end = clang_getRangeEnd(range);
            clang_getExpansionLocation(end,
                                       &file,
                                       &line,
                                       &column,
                                       0);

            const auto spelling = clang_getCursorSpelling(cursor);
            cout << line << ":" << column;
            cout << "#class:" << clang_getCString(spelling);

            const auto display = clang_getCursorUSR(cursor);
            std::cout << "," << clang_getCString(display);
            cout << endl;

        }
    }

    if (kind==CXCursor_Constructor
     || kind==CXCursor_Destructor
     || kind==CXCursor_CXXMethod
//   || kind==CXCursor_DeclRefExpr
//   || kind==CXCursor_TemplateRef
     || kind==CXCursor_FunctionTemplate
     || kind==CXCursor_MemberRefExpr
     || kind==CXCursor_FunctionDecl)
    {

        if (!clang_isCursorDefinition(cursor)) {
            CXCursor cursorDef   = clang_getCursorDefinition(cursor);
            CXCursor nullCursor = clang_getNullCursor();
            if (!clang_equalCursors(cursorDef, nullCursor)) {
                CXSourceRange    range = clang_getCursorExtent(cursorDef);

                CXSourceLocation start = clang_getRangeStart(range);

                CXFile      file;
                unsigned    line, column;

                clang_getExpansionLocation(start,
                                           &file,
                                           &line,
                                           &column,
                                           0);

                const char *dest = clang_getCString(clang_getFileName(file));
                std::cout << currentFilename << "@";
                std::cout << fromLine << ":" << fromColumn << "-"
                          << toLine << ":" << toColumn
                          << "->" << dest
                          << "@" << line;

                CXSourceLocation end = clang_getRangeEnd(range);
                clang_getExpansionLocation(end,
                                           &file,
                                           &line,
                                           &column,
                                           0);

                std::cout << "-" << line << "[" << kind << ":";

                const auto spelling = clang_getCursorSpelling(cursor);
                std::cout << clang_getCString(spelling);

                const auto display = clang_getCursorUSR(cursor);
                std::cout << "],[" << clang_getCString(display);

                std::cout << "]" << std::endl;


            } else {
                /*
                std::cout << currentFilename << "@";
                std::cout << fromLine << ":" << fromColumn << "-"
                              << toLine << ":" << toColumn
                              << "->";
                std::cout << "[can not find definition]"
                          << "[" << kind << ":";
                const auto spelling = clang_getCursorSpelling(cursor);
                std::cout << clang_getCString(spelling);
                std::cout << "]" << std::endl;
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

    if (argc<2) {
        std::cerr << "usage: " << argv[0] << " ... sourcefile" << std::endl;
        return 2;
    }

    Data  data(argv[argc-1]);

    std::cerr << "[INFO] Searching in '" << data.headerfile
              << "' for declarations " << std::endl
              << "       defined in '" << data.sourcefile
              << "' ..." << std::endl;

    CXTranslationUnit tu = clang_parseTranslationUnit(index, argv[argc-1],
                                                      argv+1, argc-2,
                                                      0, 0,
                                                      CXTranslationUnit_None);

    unsigned n = clang_getNumDiagnostics(tu);
    if (n) {
        for (unsigned i=0, n=clang_getNumDiagnostics(tu); i!=n; ++i) {
            CXDiagnostic diag = clang_getDiagnostic(tu, i);
            auto opt = clang_defaultDiagnosticDisplayOptions();
            CXString string = clang_formatDiagnostic(diag, opt);
            std::cerr << "[ERROR] " << clang_getCString(string) << std::endl;
            clang_disposeString(string);
        }
        return 1;
    }

    CXCursor cursor = clang_getTranslationUnitCursor(tu);

    //void *opt = (void *)(path_prefix.c_str());
    int result = clang_visitChildren(cursor, visitor, (void *)&data);

    if (result!=0) {
        std::cerr << "clang_visitChildren(...) was interupted." << std::endl;
    }

    clang_disposeTranslationUnit(tu);
    clang_disposeIndex(index);

    std::cerr << "[INFO] ... done." << std::endl;
    return 0;
}
