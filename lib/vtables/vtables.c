/*
 * cd s:\core-anatomy\kitgen\8.6\win32-ix86 && envset && nmake lite KIT_INCLUDES_SQLITE=1 KIT_INCLUDES_TWAPI=1 KIT_INCLUDES_SQLITE_VTABLE=1 VERSION=86 COPT="-Od" 
 */
#include <string.h>
#include "tcl.h"
#include "sqlite3.h"

#define PACKAGE_NAME "sqlite_vtable"
#define PACKAGE_VERSION "0.1"

/* Cached pointers to Tcl type descriptors */
static const Tcl_ObjType *gTclStringTypeP;
static const Tcl_ObjType *gTclIntTypeP;
static const Tcl_ObjType *gTclWideIntTypeP;
static const Tcl_ObjType *gTclDoubleTypeP;
static const Tcl_ObjType *gTclBooleanTypeP;
static const Tcl_ObjType *gTclBooleanStringTypeP;
static const Tcl_ObjType *gTclByteArrayTypeP;


/* TBD - implement assert */
#define VTABLE_ASSERT(cond) (void) 0

int gVTableHandleCounter;

/*
 * Holds per-interp vtable context. A context is expected to be
 * accessed from a single thread (running the interpreter) so no
 * locks are required.
 */
typedef struct _VTableInterpContext {
    Tcl_Interp *interp;
    int         nrefs;           /* Ref count for this structure */
    Tcl_HashTable dbconns;       /* Maps sqlite* -> VTableDbConnection */
} VTableInterpContext;

typedef struct _VTableDB {
    VTableInterpContext *vticP; /* Interpreter this db belongs to */
    sqlite3    *sqliteP;        /* DB connection */
    Tcl_Obj    *dbcmd_objP;     /* Corresponding Tcl command name */
    Tcl_Obj    *null_objP;      /* String rep for NULL Sql value */
    int         nrefs;          /* Ref count for this structure */
} VTableDB;

typedef struct _VTableInfo {
    struct sqlite3_vtab vtab;   /* Used by sqlite, must be first field */
    VTableDB   *vtdbP;          /* Links to owning database connection */
    Tcl_Obj    *vthandleP;      /* Identifier of the vtable for script */
    Tcl_Obj    *cmdprefixP;     /* Command callback prefix */
} VTableInfo;


const char *gNullInterpError = "Internal error: NULL database connection or deleted interpreter.";


static VTableInfo *VTableInfoNew(VTableDB *vtdbP, const char *name) 
{
    VTableInfo *vtabP;
    char buf[24];

    vtabP = (VTableInfo *) ckalloc(sizeof(*vtabP));
    /* Note sqlite3 takes care of initalizing vtabP->vtab, just zero it */
    memset(&vtabP->vtab, 0, sizeof(vtabP->vtab));
    vtabP->vtdbP = vtdbP;
    vtabP->cmdprefixP = NULL;
    sqlite3_snprintf(sizeof(buf), buf, "vt%d",  ++gVTableHandleCounter);
    vtabP->vthandleP = Tcl_NewStringObj(buf, -1);
    Tcl_IncrRefCount(vtabP->vthandleP);

    return vtabP;
}

static void VTableInfoDelete(VTableInfo *vtabP)
{
    if (vtabP->vthandleP) {
        Tcl_DecrRefCount(vtabP->vthandleP);
    }
    if (vtabP->cmdprefixP) {
        Tcl_DecrRefCount(vtabP->cmdprefixP);
    }
    ckfree((char*)vtabP);
}


static VTableInterpContext *VTICNew(Tcl_Interp *interp)
{
    VTableInterpContext *vticP = (VTableInterpContext *)ckalloc(sizeof(*vticP));
    vticP->interp = interp;
    vticP->nrefs = 0;
    Tcl_InitHashTable(&vticP->dbconns, TCL_ONE_WORD_KEYS);
    return vticP;
}

#define VTICRef(vticP_, incr_) do { (vticP_)->nrefs += (incr_); } while (0)

static void VTICUnref(VTableInterpContext *vticP, int decr)
{
    vticP->nrefs -= decr;
    /* Note nrefs can be < 0, when freeing from an initial allocation */
    if (vticP->nrefs <= 0) {
        // TBD - free vticP->dbconns hash values (as opposed to keys)
        Tcl_DeleteHashTable(&vticP->dbconns);
        ckfree((char *) vticP);
    }
}

static VTableDB *VTDBNew(void)
{
    VTableDB *vtdbP = (VTableDB *) ckalloc(sizeof(*vtdbP));
    vtdbP->sqliteP = NULL;
    vtdbP->vticP = NULL;
    vtdbP->dbcmd_objP = NULL;
    vtdbP->null_objP = Tcl_NewObj();
    Tcl_IncrRefCount(vtdbP->null_objP);
    vtdbP->nrefs = 0;
    return vtdbP;
}

#define VTDBRef(vtdbP_, incr_) do { (vtdbP_)->nrefs += (incr_); } while (0)

static void VTDBUnref(VTableDB *vtdbP, int decr)
{
    vtdbP->nrefs -= decr;
    
    /* Note nrefs can be < 0, when freeing from an initial allocation */
    if (vtdbP->nrefs <= 0) {
        // TBD 
        if (vtdbP->dbcmd_objP) {
            Tcl_DecrRefCount(vtdbP->dbcmd_objP);
        }
        if (vtdbP->null_objP) {
            Tcl_DecrRefCount(vtdbP->null_objP);
        }
        if (vtdbP->vticP)
            VTICUnref(vtdbP->vticP, 1);
        ckfree((char *) vtdbP);
    }
}

/* Should only be called from sqlite, never directly */
static void VTDBDetachSqliteCallback(VTableDB *vtdbP)
{
    vtdbP->sqliteP = NULL;
    VTDBUnref(vtdbP, 1);
}


int ReturnSqliteError(Tcl_Interp *interp, sqlite3 *sqliteP, char *msg)
{
    const char *sqlite_msg;
    const char *separator;

    Tcl_ResetResult(interp);

    if (msg == NULL)
        msg = "";


    sqlite_msg = sqliteP ? sqlite3_errmsg(sqliteP) : "";

    separator = msg[0] && sqlite_msg[0] ? " " : "";

    Tcl_AppendResult(interp, msg, separator, sqlite_msg, NULL);
    return TCL_ERROR;
}


static void SetVTableError(VTableInfo *vtabP, const char *msg)
{
    if (vtabP->vtab.zErrMsg)
        sqlite3_free(vtabP->vtab.zErrMsg);
    vtabP->vtab.zErrMsg = sqlite3_mprintf("%s", msg);
}

static void SetVTableErrorFromObj(VTableInfo *vtabP, Tcl_Obj *objP)
{
    SetVTableError(vtabP, Tcl_GetString(objP));
}

static void SetVTableErrorFromInterp(VTableInfo *vtabP, Tcl_Interp *interp)
{
    SetVTableErrorFromObj(vtabP, Tcl_GetObjResult(interp));
}

static int InitNullValueForDB(Tcl_Interp *interp, VTableDB *vtdbP)
{
    Tcl_Obj *objv[2];
    int status;

    objv[0] = vtdbP->dbcmd_objP; /* No need to IncrRef this as vtdbP
                                    already ensures that */
    objv[1] = Tcl_NewStringObj("nullvalue", -1);
    Tcl_IncrRefCount(objv[1]);

    status = Tcl_EvalObjv(interp, 2, objv, TCL_EVAL_DIRECT|TCL_EVAL_GLOBAL);
    Tcl_DecrRefCount(objv[1]);

    if (status == TCL_ERROR)
        return TCL_ERROR;

    if (vtdbP->null_objP)
        Tcl_DecrRefCount(vtdbP->null_objP);
    vtdbP->null_objP = Tcl_GetObjResult(interp);
    Tcl_IncrRefCount(vtdbP->null_objP);
    return TCL_OK;
}


static Tcl_Obj *ObjFromPtr(void *p, char *name)
{
    Tcl_Obj *objs[2];
    objs[0] = Tcl_NewWideIntObj((Tcl_WideInt)p);
    objs[1] = Tcl_NewStringObj(name ? name : "void*", -1);
    return Tcl_NewListObj(2, objs);
}


int ObjToPtr(Tcl_Interp *interp, Tcl_Obj *obj,  char *name, void **pvP)
{
    Tcl_Obj **objsP;
    int       nobj;
    Tcl_WideInt val;

    if (Tcl_ListObjGetElements(interp, obj, &nobj, &objsP) != TCL_OK)
        return TCL_ERROR;
    if (nobj != 2) {
        /* We accept NULL and 0 as a valid pointer of any type */
        if (nobj == 1 &&
            (strcmp(Tcl_GetString(obj), "NULL") == 0 ||
             (Tcl_GetWideIntFromObj(interp, obj, &val) == TCL_OK && val == 0))) {
            *pvP = 0;
            return TCL_OK;
        }

        if (interp) {
            Tcl_ResetResult(interp); /* GetInt above might have set result */
            Tcl_AppendResult(interp, "Invalid pointer or opaque value: '",
                             Tcl_GetString(obj), "'.", NULL);
        }
        return TCL_ERROR;
    }

    /* If a type name is specified, see that it matches. Else any type ok */
    if (name) {
        char *s = Tcl_GetString(objsP[1]);
        if (strcmp(s, name)) {
            if (interp) {
                Tcl_AppendResult(interp, "Unexpected type '", s, "', expected '",
                                 name, "'.", NULL);
                return TCL_ERROR;
            }
        }
    }
    
    if (Tcl_GetWideIntFromObj(interp, objsP[0], &val) != TCL_OK) {
        if (interp)
            Tcl_AppendResult(interp, "Invalid pointer or opaque value '",
                             Tcl_GetString(objsP[0]), "'.", NULL);
        return TCL_ERROR;
    }
    *pvP = (void*) val;
    return TCL_OK;
}

void ObjToSqliteContextValue(Tcl_Obj *objP, sqlite3_context *sqlctxP)
{
    unsigned char *data;
    int len;
    if (objP->typePtr) {
        /*
         * Note there is no return code checking here. Once the typePtr
         * is checked, the corresponding Tcl_Get* function should
         * always succeed.
         */

        if (objP->typePtr == gTclStringTypeP) {
            /*
             * Do nothing, fall thru below to handle as default type.
             * This check is here just so the most common case of text
             * columns does not needlessly go through other type checks.
             */
        } else if (objP->typePtr == gTclIntTypeP) {
            int ival;
            Tcl_GetIntFromObj(NULL, objP, &ival);
            sqlite3_result_int(sqlctxP, ival);
            return;
        } else if (objP->typePtr == gTclWideIntTypeP) {
            Tcl_WideInt i64val;
            Tcl_GetWideIntFromObj(NULL, objP, &i64val);
            sqlite3_result_int64(sqlctxP, i64val);
            return;
        } else if (objP->typePtr == gTclDoubleTypeP) {
            double dval;
            Tcl_GetDoubleFromObj(NULL, objP, &dval);
            sqlite3_result_double(sqlctxP, dval);
            return;
        } else if (objP->typePtr == gTclBooleanTypeP ||
                   objP->typePtr == gTclBooleanStringTypeP) {
            int bval;
            Tcl_GetBooleanFromObj(NULL, objP, &bval);
            sqlite3_result_int(sqlctxP, bval);
            return;
        } else if (objP->typePtr == gTclByteArrayTypeP) {
            /* TBD */
            data = Tcl_GetByteArrayFromObj(objP, &len);
            sqlite3_result_blob(sqlctxP, data, len, SQLITE_TRANSIENT);
            return;
        }
    }

    /* Handle everything else as text by default */
    data = (unsigned char *)Tcl_GetStringFromObj(objP, &len);
    sqlite3_result_text(sqlctxP, data, len, SQLITE_TRANSIENT);
}

static Tcl_Obj *ObjFromSqliteValue(sqlite3_value *sqlvalP, VTableDB *vtdbP)
{
    int   len;
    sqlite_int64 i64;

    /* The following uses the same call sequences for conversion
       as in the sqlite tclSqlFunc function. */
    switch (sqlite3_value_type(sqlvalP)) {
    case SQLITE_INTEGER:
        /* Ints are always 64 bit in sqlite3 values */
        i64 = sqlite3_value_int64(sqlvalP);
        if (i64 >= -2147483647 && i64 <= 2147483647)
            return Tcl_NewIntObj((int) i64);
        else
            return Tcl_NewWideIntObj(i64);

    case SQLITE_FLOAT:
        return Tcl_NewDoubleObj(sqlite3_value_double(sqlvalP));

    case SQLITE_BLOB:
        len = sqlite3_value_bytes(sqlvalP);
        return Tcl_NewByteArrayObj(sqlite3_value_blob(sqlvalP), len);
        
    case SQLITE_NULL:
        /*
         * Note we do not increment the ref count for nullObjP. The caller
         * has to be careful to not unref without doing a ref first else
         * vtdbP->nullObjP will be a dangling pointer with bad results.
         */
        return vtdbP->null_objP;

    case SQLITE_TEXT:
    default:
        len = sqlite3_value_bytes(sqlvalP);
        return Tcl_NewStringObj((char *)sqlite3_value_text(sqlvalP), len);
    }
}

static Tcl_Obj *ObjFromSqliteValueArray(int argc, sqlite3_value *argv[], VTableDB *vtdbP)
{
    Tcl_Obj *objP = Tcl_NewListObj(0, NULL);
    int i;
    for (i = 0; i < argc; ++i) {
        Tcl_ListObjAppendElement(NULL, objP, ObjFromSqliteValue(argv[i], vtdbP));
    }
    return objP;
}



/* 
 * Given a command corresponding to a Sqlite connection, return
 * the corresponding sqlite3* pointer. This is stored as the clientdata
 * field for the corresponding Tcl command.
 */
static int GetSqliteConnPtr(Tcl_Interp *interp, const char *db_cmd, sqlite3 **dbPP){
    Tcl_CmdInfo cmdInfo;
    if( Tcl_GetCommandInfo(interp, db_cmd, &cmdInfo) ){
        void *p = cmdInfo.objClientData;
        /* The sqlite3 pointer is *always* the first field */
        *dbPP = *(sqlite3 **)p;
        return TCL_OK;
    } else {
        Tcl_AppendResult(interp, "Unknown database connection '", db_cmd, "'", NULL);
        return TCL_ERROR;
    }
}

/*
 * Invoke the command for the specified virtual table with the additional
 * args passed in. Note the additional arg objs are unref'ed eventually so 
 * caller must protect them with ref counts if they accessed on return.
 */
static int VTableInvokeCmd(Tcl_Interp *interp, VTableInfo *vtabP,
                           const char *command, int argobjc, Tcl_Obj **argobjv)
{
    Tcl_Obj *objv[32];
    Tcl_Obj **prefix;
    int nprefix;
    int objc;
    int i;
    int status;
    
    Tcl_ListObjGetElements(interp, vtabP->cmdprefixP, &nprefix, &prefix);
    objc = nprefix + 1 + 1 + argobjc;
    if (objc > (sizeof(objv)/sizeof(objv[0]))) {
        Tcl_SetResult(interp, "Exceeded limit on number of arguments allowed for virtual table method", TCL_STATIC);
        return TCL_ERROR;
    }

    for (i = 0 ; i < nprefix; ++i) {
        objv[i] = prefix[i];
        Tcl_IncrRefCount(objv[i]);
    }

    /* Tack on method such as "update" */
    objv[nprefix] = Tcl_NewStringObj(command, -1);
    Tcl_IncrRefCount(objv[nprefix]);

    /* Tack on virtual table handle */
    objv[nprefix+1] = vtabP->vthandleP;
    Tcl_IncrRefCount(objv[nprefix+1]);

    nprefix += 2;

    /* Finally, extra arguments */
    for (i = 0; i < argobjc; ++i) {
        objv[i + nprefix] = argobjv[i];
        Tcl_IncrRefCount(argobjv[i]);
    }

    status = Tcl_EvalObjv(interp, objc, objv, TCL_EVAL_DIRECT|TCL_EVAL_GLOBAL);

    for (i = 0; i < objc; ++i) {
        Tcl_DecrRefCount(objv[i]);
    }

    return status;
}

static int VTableDisconnectOrDestroy(VTableInfo *vtabP, int destroy)
{
    if (vtabP->vtdbP && vtabP->vtdbP->vticP->interp) {
        VTableInvokeCmd(vtabP->vtdbP->vticP->interp, vtabP,
                        destroy ? "xDestroy" : "xDisconnect",
                        0, NULL);
        /* Result is ignored */
    }

    VTableInfoDelete(vtabP);
    return SQLITE_OK;
}


static int VTableCreateOrConnect(
    sqlite3 *sqliteP,
    void *clientdata,
    int argc,
    const char *const *argv,
    sqlite3_vtab **vtabPP,
    char **errstrP,
    int create)
{
    VTableDB *vtdbP = (VTableDB *)clientdata;
    VTableInfo *vtabP;
    int status;
    int i;
    Tcl_Obj *objv[4];
    Tcl_Interp *interp = vtdbP->vticP->interp;

    /*
     * argv[0] - name of our module (i.e. PACKAGE_NAME)
     * argv[1] - name of database where the virtual table is being created
     * argv[2] - name of the table
     * argv[3..argc-1] - arguments passed to CREATE VIRTUAL TABLE. argv[3]
     *   is the script to invoke, remaining are arguments passed
     *   only to the create and connect methods.
     */
    VTABLE_ASSERT(vtdbP->sqliteP == sqliteP);

    if (argc < 4) {
        *errstrP = sqlite3_mprintf("Insufficient number of arguments for virtual table");
        return SQLITE_ERROR;
    }
    
    vtabP = VTableInfoNew(vtdbP, argv[2]);

    /*
     * argv[3] is the command prefix to be invoked for virtual
     * table operations.
     */
    vtabP->cmdprefixP = Tcl_NewStringObj(argv[3], -1);
    Tcl_IncrRefCount(vtabP->cmdprefixP);
    if (Tcl_ListObjLength(interp, vtabP->cmdprefixP, &i) != TCL_OK) {
        *errstrP = sqlite3_mprintf("Command prefix '%s' does not have a valid list format.", argv[3]);
        VTableInfoDelete(vtabP);
        return SQLITE_ERROR;
    }

    objv[0] = vtdbP->dbcmd_objP;
    objv[1] = Tcl_NewStringObj(argv[1], -1);  /* DB name */
    objv[2] = Tcl_NewStringObj(argv[2], -1); /* virtual table name */
    objv[3] = Tcl_NewListObj(0, NULL);
    for (i = 4; i < argc; ++i) {
        Tcl_ListObjAppendElement(interp, objv[3], Tcl_NewStringObj(argv[i],-1));
    }
    if (VTableInvokeCmd(interp, vtabP, create ? "xCreate" : "xConnect",
                        4, objv) != TCL_OK) {
        *errstrP = sqlite3_mprintf("%s", Tcl_GetStringResult(interp));
        VTableInfoDelete(vtabP);
        return SQLITE_ERROR;
    }

    /* Return value is DDL that we have to use to create the table */
    status = sqlite3_declare_vtab(sqliteP, Tcl_GetStringResult(interp));
    if (status != SQLITE_OK) {
        VTableDisconnectOrDestroy(vtabP, create); /* Will also delete vtabP */
        return status;
    }

    *vtabPP = &vtabP->vtab;
    return SQLITE_OK;
}


static int xCreate(
    sqlite3 *sqliteP,
    void *clientdata,
    int argc,
    const char *const *argv,
    sqlite3_vtab **vtabPP,
    char **errstrP)
{
    return VTableCreateOrConnect(sqliteP, clientdata, argc, argv, vtabPP, errstrP, 1);
}

static int xConnect(
    sqlite3 *sqliteP,
    void *clientdata,
    int argc,
    const char *const *argv,
    sqlite3_vtab **vtabPP,
    char **errstrP)
{
    return VTableCreateOrConnect(sqliteP, clientdata, argc, argv, vtabPP, errstrP, 0);
}

int xBestIndex(sqlite3_vtab *sqltabP, sqlite3_index_info *infoP)
{
    VTableInfo *vtabP = (VTableInfo *) sqltabP;
    Tcl_Obj *objv[3];
    Tcl_Interp *interp;
    Tcl_Obj *constraints;
    Tcl_Obj *order;
    int i;
    char *s;
    Tcl_Obj **response;
    int   nobjs;
    Tcl_Obj **usage;
    int       nusage;

    if (vtabP->vtdbP == NULL || (interp = vtabP->vtdbP->vticP->interp) == NULL) {
        /* Should not really happen */
        SetVTableError(vtabP, gNullInterpError);
        return SQLITE_ERROR;
    }

    constraints = Tcl_NewListObj(0, NULL);
    for (i = 0; i < infoP->nConstraint; ++i) {
        objv[0] = Tcl_NewIntObj(infoP->aConstraint[i].iColumn);
        switch (infoP->aConstraint[i].op) {
        case 2: s = "eq" ; break;
        case 4: s = "gt" ; break;
        case 8: s = "le" ; break;
        case 16: s = "lt" ; break;
        case 32: s = "ge" ; break;
        case 64: s = "match"; break;
        default:
            SetVTableError(vtabP, "Unknown or unsupported constraint operator.");
            return SQLITE_ERROR;
        }
        objv[1] = Tcl_NewStringObj(s, -1);
        objv[2] = Tcl_NewBooleanObj(infoP->aConstraint[i].usable);
        Tcl_ListObjAppendElement(interp, constraints, Tcl_NewListObj(3, objv));
    }

    order = Tcl_NewListObj(0, NULL);
    for (i = 0; i < infoP->nOrderBy; ++i) {
        objv[0] = Tcl_NewIntObj(infoP->aOrderBy[i].iColumn);
        objv[1] = Tcl_NewBooleanObj(infoP->aOrderBy[i].desc);
        Tcl_ListObjAppendElement(interp, order, Tcl_NewListObj(2, objv));
    }

    objv[0] = constraints;
    objv[1] = order;
    if (VTableInvokeCmd(interp, vtabP, "xBestIndex", 2, objv) != TCL_OK) {
        SetVTableErrorFromInterp(vtabP, interp);
        return SQLITE_ERROR;
    }

    /* Parse and return the response */
    if (Tcl_ListObjGetElements(interp, Tcl_GetObjResult(interp),
                               &nobjs, &response) != TCL_OK)
        goto bad_response;

    if (nobjs == 0)
        return SQLITE_OK;

    if (nobjs != 5) {
        /* If non-empty, list must have exactly five elements */
        goto bad_response;
    }

    if (Tcl_ListObjGetElements(interp, response[0],
                               &nusage, &usage) != TCL_OK
        || nusage > infoP->nConstraint) {
        /*
         * Length of constraints used must not be greater than original
         * number of constraints
         * TBD - should it be exactly equal ?
         */
        goto bad_response;
    }

    for (i = 0; i < nusage; ++i) {
        Tcl_Obj **usage_constraint;
        int nusage_constraint;
        int argindex;
        int omit;
        if (Tcl_ListObjGetElements(interp, usage[i],
                                   &nusage_constraint, &usage_constraint) != TCL_OK
            || nusage_constraint != 2
            || Tcl_GetIntFromObj(interp, usage_constraint[0], &argindex) != TCL_OK
            || Tcl_GetBooleanFromObj(interp, usage_constraint[1], &omit) != TCL_OK
            ) {
            goto bad_response;
        }
        infoP->aConstraintUsage[i].argvIndex = argindex;
        infoP->aConstraintUsage[i].omit = omit;
    }
    
    if (Tcl_GetIntFromObj(interp, response[1], &infoP->idxNum) != TCL_OK)
        goto bad_response;
    
    s = Tcl_GetStringFromObj(response[2], &i);
    if (i) {
        infoP->idxStr = sqlite3_mprintf("%s", s);
        infoP->needToFreeIdxStr = 1;
    }

    if (Tcl_GetIntFromObj(interp, response[3], &infoP->orderByConsumed) != TCL_OK)
        goto bad_response;

    if (Tcl_GetDoubleFromObj(interp, response[4], &infoP->estimatedCost) != TCL_OK)
        goto bad_response;

    return SQLITE_OK;
    

bad_response:
    SetVTableError(vtabP, "Malformed response from virtual table script.");
    return SQLITE_ERROR;
}


static int xDisconnect(sqlite3_vtab *vtabP)
{
    return VTableDisconnectOrDestroy((VTableInfo *)vtabP, 0);
}

static int xDestroy(sqlite3_vtab *vtabP)
{
    return VTableDisconnectOrDestroy((VTableInfo *)vtabP, 1);
}

static int xOpen(sqlite3_vtab *sqltabP, sqlite3_vtab_cursor **cursorPP)
{
    sqlite3_vtab_cursor *cursorP;
    VTableInfo *vtabP = (VTableInfo *) sqltabP;
    Tcl_Obj *curobjP;
    Tcl_Interp *interp;

    if (vtabP->vtdbP == NULL || (interp = vtabP->vtdbP->vticP->interp) == NULL) {
        /* Should not really happen */
        SetVTableError(vtabP, gNullInterpError);
        return SQLITE_ERROR;
    }

    cursorP = (sqlite3_vtab_cursor *)ckalloc(sizeof(*cursorP));

    curobjP = ObjFromPtr(cursorP, "sqlite3_vtab_cursor*");
    if (VTableInvokeCmd(interp, vtabP, "xOpen", 1, &curobjP)
        != TCL_OK) {
        SetVTableErrorFromInterp(vtabP, interp);
        ckfree((char *)cursorP);
        return SQLITE_ERROR;
    }

    *cursorPP = cursorP;
    return SQLITE_OK;
}


int xClose(sqlite3_vtab_cursor *cursorP)
{
    VTableInfo *vtabP = (VTableInfo *) cursorP->pVtab;
    Tcl_Interp *interp;

    if (vtabP->vtdbP && (interp = vtabP->vtdbP->vticP->interp) != NULL) {
        Tcl_Obj *curobjP;
        curobjP = ObjFromPtr(cursorP, "sqlite3_vtab_cursor*");
        VTableInvokeCmd(interp, vtabP, "xClose", 1, &curobjP);
        /* Return value ignored */
    }

    ckfree((char *)cursorP);
    return SQLITE_OK;
}

int xFilter(sqlite3_vtab_cursor *cursorP, int idx, const char *idxstrP,
            int argc, sqlite3_value **argv)
{
    VTableInfo *vtabP = (VTableInfo *) cursorP->pVtab;
    Tcl_Obj *objv[4];
    Tcl_Interp *interp;
    int i;

    if (vtabP->vtdbP == NULL || (interp = vtabP->vtdbP->vticP->interp) == NULL) {
        /* Should not really happen */
        SetVTableError(vtabP, gNullInterpError);
        return SQLITE_ERROR;
    }

    objv[0] = ObjFromPtr(cursorP, "sqlite3_vtab_cursor*");
    objv[1] = Tcl_NewIntObj(idx);
    objv[2] = Tcl_NewStringObj(idxstrP ? idxstrP : "", -1);
    objv[3] = Tcl_NewListObj(0, NULL);
    for (i = 0; i < argc; ++i) {
        Tcl_ListObjAppendElement(NULL, objv[3], ObjFromSqliteValue(argv[i], vtabP->vtdbP));
    }

    if (VTableInvokeCmd(interp, vtabP, "xFilter", 4 , objv) != TCL_OK) {
        SetVTableErrorFromInterp(vtabP, interp);
        return SQLITE_ERROR;
    }
    return SQLITE_OK;
}

int xNext(sqlite3_vtab_cursor *cursorP)
{
    VTableInfo *vtabP = (VTableInfo *) cursorP->pVtab;
    Tcl_Obj *curobjP;
    Tcl_Interp *interp;

    if (vtabP->vtdbP == NULL || (interp = vtabP->vtdbP->vticP->interp) == NULL) {
        /* Should not really happen */
        SetVTableError(vtabP, gNullInterpError);
        return SQLITE_ERROR;
    }

    curobjP = ObjFromPtr(cursorP, "sqlite3_vtab_cursor*");
    if (VTableInvokeCmd(interp, vtabP, "xNext", 1, &curobjP) != TCL_OK) {
        SetVTableErrorFromInterp(vtabP, interp);
        return SQLITE_ERROR;
    }

    return SQLITE_OK;
}

int xEof(sqlite3_vtab_cursor *cursorP)
{
    VTableInfo *vtabP = (VTableInfo *) cursorP->pVtab;
    Tcl_Obj *curobjP;
    Tcl_Obj *resultObj;
    int ateof;
    Tcl_Interp *interp;

    if (vtabP->vtdbP == NULL || (interp = vtabP->vtdbP->vticP->interp) == NULL) {
        /* Should not really happen */
        SetVTableError(vtabP, gNullInterpError);
        return 1;               /* EOF */
    }

    curobjP = ObjFromPtr(cursorP, "sqlite3_vtab_cursor*");
    if (VTableInvokeCmd(interp, vtabP, "xEof", 1, &curobjP) != TCL_OK) {
        SetVTableErrorFromInterp(vtabP, interp);
        return 1;               /* eof */
    }

    resultObj = Tcl_GetObjResult(interp);
    if (Tcl_GetBooleanFromObj(interp, resultObj, &ateof) == TCL_OK)
        return ateof;
    else
        return 1;               /* eof on error */
}

int xColumn(sqlite3_vtab_cursor *cursorP, sqlite3_context *ctxP, int colindex)
{
    VTableInfo *vtabP = (VTableInfo *) cursorP->pVtab;
    Tcl_Obj *objv[2];
    Tcl_Interp *interp;

    if (vtabP->vtdbP == NULL || (interp = vtabP->vtdbP->vticP->interp) == NULL) {
        /* Should not really happen */
        SetVTableError(vtabP, gNullInterpError);
        return SQLITE_ERROR;
    }

    objv[0] = ObjFromPtr(cursorP, "sqlite3_vtab_cursor*");
    objv[1] = Tcl_NewIntObj(colindex);
    switch (VTableInvokeCmd(interp, vtabP, "xColumn", 2, objv)) {
    case TCL_OK:
        ObjToSqliteContextValue(Tcl_GetObjResult(interp), ctxP);
        return SQLITE_OK;
    case TCL_RETURN:
        /* Treat as SQL NULL value. Simply don't call any sqlite3_result_* */
        return SQLITE_OK;
    default:
        sqlite3_result_error(ctxP, Tcl_GetStringResult(interp), -1); 
        return SQLITE_ERROR;
    }
}

int xRowid(sqlite3_vtab_cursor *cursorP, sqlite_int64 *rowidP)
{
    VTableInfo *vtabP = (VTableInfo *) cursorP->pVtab;
    Tcl_Obj *curobjP;
    Tcl_Obj *resultObj;
    Tcl_Interp *interp;
    Tcl_WideInt rowid;

    if (vtabP->vtdbP == NULL || (interp = vtabP->vtdbP->vticP->interp) == NULL) {
        /* Should not really happen */
        SetVTableError(vtabP, gNullInterpError);
        return SQLITE_ERROR;
    }

    curobjP = ObjFromPtr(cursorP, "sqlite3_vtab_cursor*");
    if (VTableInvokeCmd(interp, vtabP, "xRowid", 1, &curobjP) != TCL_OK) {
        SetVTableErrorFromInterp(vtabP, interp);
        return SQLITE_ERROR;               /* eof */
    }

    resultObj = Tcl_GetObjResult(interp);
    if (Tcl_GetWideIntFromObj(interp, resultObj, &rowid) != TCL_OK) {
        SetVTableErrorFromInterp(vtabP, interp);
        return SQLITE_ERROR;
    }

    *rowidP = rowid;
    return SQLITE_OK;
}

static int xUpdate(sqlite3_vtab *sqltabP, int argc, sqlite3_value **argv, sqlite_int64 *rowidP)
{
    VTableInfo *vtabP = (VTableInfo *) sqltabP;
    Tcl_Obj *objv[4];
    int objc;
    Tcl_Obj *resultObj;
    Tcl_Interp *interp;
    sqlite3_int64 rowid = 0, rowid2;
    int return_rowid;

    if (vtabP->vtdbP == NULL || (interp = vtabP->vtdbP->vticP->interp) == NULL) {
        /* Should not really happen */
        SetVTableError(vtabP, gNullInterpError);
        return SQLITE_ERROR;
    }


    if (argc == 1) {
        objv[0] = Tcl_NewStringObj("delete", -1);
        objv[1] = ObjFromSqliteValue(argv[0], vtabP->vtdbP);
        objc = 2;
        return_rowid = 0;
    } else {
        return_rowid = (sqlite3_value_type(argv[1]) == SQLITE_NULL);
        if (sqlite3_value_type(argv[0]) == SQLITE_NULL) {
            objv[0] = Tcl_NewStringObj("insert", -1);
            objv[1] = ObjFromSqliteValue(argv[1], vtabP->vtdbP);/* New row id */
            objc = 3;
        } else {
            rowid = sqlite3_value_int64(argv[0]);
            objv[1] = Tcl_NewWideIntObj(rowid); /* Old row id */
            if (return_rowid ||
                (rowid2 = sqlite3_value_int64(argv[1])) != rowid) {
                objv[0] = Tcl_NewStringObj("replace", -1);
                objv[2] = ObjFromSqliteValue(argv[1], vtabP->vtdbP);
                objc = 4;
            } else {
                objv[0] = Tcl_NewStringObj("modify", -1);
                objc = 3;
            }
        }
        objv[objc-1] = ObjFromSqliteValueArray(argc-2, argv+2, vtabP->vtdbP);
    }

    if (VTableInvokeCmd(interp, vtabP, "xUpdate", objc, objv) != TCL_OK) {
        SetVTableErrorFromInterp(vtabP, interp);
        return SQLITE_ERROR;               /* eof */
    }

    if (return_rowid) {
        resultObj = Tcl_GetObjResult(interp);
        if (Tcl_GetWideIntFromObj(NULL, resultObj, &rowid) == TCL_OK) {
            *rowidP = rowid;
        } else {
            SetVTableError(vtabP, "Update script did not return integer row id.");
            return SQLITE_ERROR;
        }
    }

    return SQLITE_OK;
}


static int TransactionOp(sqlite3_vtab *sqltabP, const char *op)
{
    Tcl_Interp *interp;
    VTableInfo *vtabP = (VTableInfo *)sqltabP;

    if (vtabP->vtdbP == NULL || (interp = vtabP->vtdbP->vticP->interp) == NULL) {
        /* Should not really happen, */
        SetVTableError(vtabP, gNullInterpError);
        return SQLITE_ERROR;
    }

    if (VTableInvokeCmd(interp, vtabP, op, 0, NULL) == TCL_OK)
        return SQLITE_OK;
    else {
        SetVTableErrorFromInterp(vtabP, interp);
        return SQLITE_ERROR;
    }

}

static int xBegin(sqlite3_vtab *sqltabP)
{
    return TransactionOp(sqltabP, "xBegin");
}

static int xSync(sqlite3_vtab *sqltabP)
{
    return TransactionOp(sqltabP, "xSync");
}

static int xCommit(sqlite3_vtab *sqltabP)
{
    return TransactionOp(sqltabP, "xCommit");
}

static int xRollback(sqlite3_vtab *sqltabP)
{
    return TransactionOp(sqltabP, "xRollback");
}


static int xRename(sqlite3_vtab *sqltabP, const char *newnameP)
{
    /* TBD - when is rename used? Should we permit renaming ? */
    return SQLITE_ERROR;
}

static sqlite3_module sqlite_vtable_methods = {
  0,                    /* iVersion */
  xCreate,
  xConnect,
  xBestIndex,
  xDisconnect,
  xDestroy,
  xOpen,             /* open a cursor */
  xClose,            /* close a cursor */
  xFilter,
  xNext,             /* advance a cursor */
  xEof,              /* check for end of scan */
  xColumn,
  xRowid,
  xUpdate,
  xBegin,
  xSync,
  xCommit,
  xRollback,
  0,                         /* xFindMethod - TBD */
  xRename,
};



/* attach_connection DBCONN */
static int AttachConnectionObjCmd(void *clientdata,
                                  Tcl_Interp *interp,
                                  int objc,
                                  Tcl_Obj * const *objv)
{
    VTableInterpContext *vticP = (VTableInterpContext *)clientdata;
    VTableDB *vtdbP;
    sqlite3 *sqliteP;
    int new_entry;

    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, " DBCONN");
        return TCL_ERROR;
    }

    /* Map the db connection command to the connection pointer */
    if (GetSqliteConnPtr(interp, Tcl_GetString(objv[1]), &sqliteP) != TCL_OK)
        return TCL_ERROR;

    /* Check if already registered the virtual table module for this conn. */
    
    if (Tcl_FindHashEntry(&vticP->dbconns, sqliteP) != NULL)
        return TCL_OK;

    /* Need to register for this db conn */
    vtdbP = VTDBNew();
    Tcl_IncrRefCount(objv[1]);
    vtdbP->dbcmd_objP = objv[1];

    /* Find out the NULL value representation this DB is using */
    if (InitNullValueForDB(interp, vtdbP)) {
        VTDBUnref(vtdbP, 1);
        return TCL_ERROR;
    }

    if (sqlite3_create_module_v2(sqliteP, PACKAGE_NAME, &sqlite_vtable_methods,
                                 vtdbP, VTDBDetachSqliteCallback)
        != SQLITE_OK) {
        VTDBUnref(vtdbP, 1);
        return ReturnSqliteError(interp, sqliteP, NULL);
    }
    
    /* Now add to the table of connections for this interpreter */
    Tcl_SetHashValue(Tcl_CreateHashEntry(&vticP->dbconns, sqliteP, &new_entry),
                     vtdbP);

    /* Link up various structures */
    vtdbP->sqliteP = sqliteP;
    vtdbP->vticP = vticP;
    VTICRef(vticP, 1); /* Since dbP refers to it. TBD - circular dependency? */
    VTDBRef(vtdbP, 2); /* Hash table ref + ref from sqlite */
    
    return TCL_OK;
}


static void DetachFromInterp(ClientData clientdata, Tcl_Interp *interp)
{
    VTableInterpContext *vticP = (VTableInterpContext *)clientdata;
    if (vticP) {
        vticP->interp = NULL;
        VTICUnref(vticP, 1);
    }
}

int Sqlite_vtable_Init(Tcl_Interp *interp)
{
    VTableInterpContext *vticP;

#ifdef USE_TCL_STUBS
    Tcl_InitStubs(interp, "8.5", 0);
#endif

    /*
     * Initialize the cache of Tcl type pointers (used when converting
     * to sqlite types). It's OK if any of these return NULL.
     */
    gTclBooleanTypeP = Tcl_GetObjType("boolean");
    gTclBooleanStringTypeP = Tcl_GetObjType("booleanString");
    gTclByteArrayTypeP = Tcl_GetObjType("bytearray");
    gTclDoubleTypeP = Tcl_GetObjType("double");
    gTclWideIntTypeP = Tcl_GetObjType("wideInt");
    gTclIntTypeP = Tcl_GetObjType("int");


    vticP = VTICNew(interp);
    VTICRef(vticP, 1); // VTIC is passed to interpreter commands as ClientData

    Tcl_CreateObjCommand(interp, PACKAGE_NAME "::attach_connection",
                         AttachConnectionObjCmd, vticP, 0);

    Tcl_CallWhenDeleted(interp, DetachFromInterp, vticP);


    Tcl_PkgProvide(interp, PACKAGE_NAME, PACKAGE_VERSION);
    return TCL_OK;
}
