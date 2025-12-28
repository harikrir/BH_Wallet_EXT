/**
 * 8/8/2018
 * @author Hatem 
 * @header file
 * Copyright (c) Enigma Labs 2019
 */
#import "Foundation/Foundation.h"
#import "Cordova/CDV.h"
#import <Cordova/CDVPlugin.h>
#import <PassKit/PassKit.h>
#import <WatchConnectivity/WatchConnectivity.h>


@interface AppleWallet : CDVPlugin

- (void) isAvailable:(CDVInvokedUrlCommand*)command;
- (void) checkCardEligibility:(CDVInvokedUrlCommand*)command;
- (void) checkCardEligibilityBySuffix:(CDVInvokedUrlCommand*)command;

- (void) checkPairedDevices:(CDVInvokedUrlCommand*)command;
- (void) checkPairedDevicesBySuffix:(CDVInvokedUrlCommand*)command;

- (void) startAddPaymentPass:(CDVInvokedUrlCommand*)command;
- (void) completeAddPaymentPass:(CDVInvokedUrlCommand*)command;


// NEW METHODS FOR NON UI WALLET EXTENSION
- (void) saveCardsToKeychain:(CDVInvokedUrlCommand*)command;
- (void) saveWalletStatus:(CDVInvokedUrlCommand*)command;
- (void) getWalletStatus:(CDVInvokedUrlCommand*)command;
- (void) clearWalletStatus:(CDVInvokedUrlCommand*)command;
- (void)testWalletExtension:(CDVInvokedUrlCommand*)command;
- (void)saveCardDetailsForExtension:(CDVInvokedUrlCommand*)command;

@end

