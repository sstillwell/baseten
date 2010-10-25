//
// PGTSOids.mm
// BaseTen
//
// Copyright (C) 2008 Marko Karppinen & Co. LLC.
//
// Before using this software, please review the available licensing options
// by visiting http://www.karppinen.fi/baseten/licensing/ or by contacting
// us at sales@karppinen.fi. Without an additional license, this software
// may be distributed only in compliance with the GNU General Public License.
//
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License, version 2.0,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
//
// $Id$
//

#import "PGTSOids.h"
#import "BXCollectionFunctions.h"
#import "BXLogger.h"


/**
 * \internal
 * \brief Return the value as an object.
 *
 * \sa PGTSOidValue
 */
id 
PGTSOidAsObject (Oid o)
{
    //Methods inherited from NSValue seem to return an NSValue instead of an NSNumber.
	//Thus, we use NSNumber.
    return BaseTen::ObjectValue (o);
}


@implementation NSNumber (PGTSOidAdditions)
/**
 * \internal
 * \brief Return the value as Oid.
 * \sa PGTSOidAsObject
 */
- (Oid) PGTSOidValue
{
	Oid retval = InvalidOid;
	BaseTen::ValueGetter <Oid> getter;
	BOOL status = getter (self, &retval);
	
	ExpectR (status, InvalidOid);
	return retval;
}
@end