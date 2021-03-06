//
//  ext2CheckInfoViewController.swift
//  SplitTheCheck
//
//  Created by Anya on 09/10/2018.
//  Copyright © 2018 Anna Zhulidova. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON
import RealmSwift
import MessageUI
import QuickLook

extension CheckInfoViewController: MFMailComposeViewControllerDelegate, QLPreviewControllerDelegate, QLPreviewControllerDataSource {
    //вызов actionSheet
    @objc func showActionSheet() {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let actionCancel = UIAlertAction(title: "Отмена", style: .cancel, handler: nil)
        actionSheet.addAction(actionCancel)
        
        let actionMail = UIAlertAction(title: "Отправить как HTML", style: .default, handler: {_ in self.sendByEmail()})
        let actionShare = UIAlertAction(title: "Открыть в PDF", style: .default, handler: {_ in self.openAsPDF()})
        let actionSave = UIAlertAction(title: "Сохранить чек", style: .default, handler: {_ in self.saveTheCheck()})
        actionSheet.addAction(actionMail)
        actionSheet.addAction(actionShare)
        actionSheet.addAction(actionSave)
        
        self.present(actionSheet, animated: true, completion: nil)
    }
    
    //делаем из чека html и сограняем в файл
    func createHTML() -> String {
        let pathToCheckTemplate = Bundle.main.path(forResource: "check", ofType: "html")
        let pathToCheckHeaderTemplate = Bundle.main.path(forResource: "checkHeader", ofType: "html")
        let pathToSectionHeaderTemplate = Bundle.main.path(forResource: "sectionHeader", ofType: "html")
        let pathToSectionRowTemplate = Bundle.main.path(forResource: "sectionRow", ofType: "html")
        
        do {
            var checkHTML = try String(contentsOfFile: pathToCheckTemplate!)
            
            var checkBody = ""
            var checkHeader = ""
            
            //создаем секции чека
            for i in 0..<items.count {
                var sectionBody = ""
                var sectionHeader = try String(contentsOfFile: pathToSectionHeaderTemplate!)
                var checkHeaderRow = try String(contentsOfFile: pathToCheckHeaderTemplate!)
                
                sectionHeader = sectionHeader.replacingOccurrences(of: "#SECTION_NAME#", with: guests[i].name)
                sectionHeader = sectionHeader.replacingOccurrences(of: "#SECTION_SUM#", with: String(format: "%.2f", totalSum[i]))
                sectionBody.append(sectionHeader)
                
                //создаем строки в заголовке чека
                checkHeaderRow = checkHeaderRow.replacingOccurrences(of: "#GUEST_NAME#", with: guests[i].name)
                checkHeaderRow = checkHeaderRow.replacingOccurrences(of: "#GUEST_SUM#", with: String(format: "%.2f", totalSum[i]))
                checkHeader.append(checkHeaderRow)
                
                //создаем строки секции чека
                for j in 0..<items[i].count {
                    var itemBody = try String(contentsOfFile: pathToSectionRowTemplate!)
                    
                    itemBody = itemBody.replacingOccurrences(of: "#ITEM_NAME#", with: items[i][j].name)
                    itemBody =  itemBody.replacingOccurrences(of: "#ITEM_PRICE#", with: "\(items[i][j].price)")
                    itemBody =  itemBody.replacingOccurrences(of: "#ITEM_AMOUNT#", with: items[i][j].myQtotalQ)
                    
                    var itemSum = ""
                    if items[i][j].isCountable {
                        itemSum = String(format: "%.2f", round(100*items[i][j].totalQuantity*items[i][j].price)/100)
                    } else {
                        itemSum = String(items[i][j].sum)
                    }
                    itemBody = itemBody.replacingOccurrences(of: "#ITEM_SUM#", with: itemSum)
                    
                    sectionBody.append(itemBody)
                }
                
                checkBody.append(sectionBody)
            }
            checkHTML = checkHTML.replacingOccurrences(of: "#CHECK_PLACE#", with: checkPlace)
            checkHTML = checkHTML.replacingOccurrences(of: "#CHECK_DATE#", with: checkDate)
            checkHTML = checkHTML.replacingOccurrences(of: "#CHECK_HEADER#", with: checkHeader)
            checkHTML = checkHTML.replacingOccurrences(of: "#CHECK_BODY#", with: checkBody)
            createMessageBody(text: checkHTML)
            print ("html created")
            return checkHTML
            
        } catch {
            print("Unable to open and use HTML template files.")
            return ""
        }
    }
    
    //делаем pdf
//    func pdfDataWithTableView(tableView: UITableView) {
//        let priorBounds = tableView.bounds
//        let fittedSize = tableView.sizeThatFits(CGSize(width:priorBounds.size.width, height:tableView.contentSize.height))
//        tableView.bounds = CGRect(x:0, y:0, width:fittedSize.width, height:fittedSize.height)
//        let pdfPageBounds = CGRect(x:-25, y:25, width:tableView.frame.width + 50, height:self.view.frame.height)
//        let pdfData = NSMutableData()
//        UIGraphicsBeginPDFContextToData(pdfData, pdfPageBounds,nil)
//        var pageOriginY: CGFloat = 0
//        while pageOriginY < fittedSize.height {
//            UIGraphicsBeginPDFPageWithInfo(pdfPageBounds, nil)
//            UIGraphicsGetCurrentContext()!.saveGState()
//            UIGraphicsGetCurrentContext()!.translateBy(x: 0, y: -pageOriginY)
//            tableView.layer.render(in: UIGraphicsGetCurrentContext()!)
//            UIGraphicsGetCurrentContext()!.restoreGState()
//            pageOriginY += pdfPageBounds.size.height
//        }
//        UIGraphicsEndPDFContext()
//        tableView.bounds = priorBounds
//        var docURL = (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)).first! as URL
//        docURL = docURL.appendingPathComponent("myDocument.pdf")
//        pdfData.write(to: docURL as URL, atomically: false)
//        print ("pdf created")
//        openQlPreview()
//    }
    
    func openAsPDF() {
        let HTMLContent = self.createHTML()
        let pageRenderer = UIPrintPageRenderer()
        let printFormatter = UIMarkupTextPrintFormatter(markupText: HTMLContent)
        pageRenderer.addPrintFormatter(printFormatter, startingAtPageAt: 0)
        
        let page = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4, 72 dpi
        pageRenderer.setValue(page.insetBy(dx: 0, dy: 20), forKey: "paperRect")
        pageRenderer.setValue(page.insetBy(dx: 0, dy: 20), forKey: "printableRect")
        
        let pdfData = drawPDFwithPrintPageRender(printPageRenderer: pageRenderer)
        
        var docURL = (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)).first! as URL
        docURL = docURL.appendingPathComponent("Чек_\(checkDate).pdf")
        pdfData.write(to: docURL as URL, atomically: false)
        print ("pdf created")
        openQlPreview()
    }
    
    func drawPDFwithPrintPageRender (printPageRenderer: UIPrintPageRenderer) -> NSMutableData {
        let data = NSMutableData()
        
        UIGraphicsBeginPDFContextToData(data, .zero, nil)
        
        for i in 0..<printPageRenderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            printPageRenderer.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()
        
        return data
    }
    
    func openQlPreview() {
        let preview = QLPreviewController.init()
        preview.dataSource = self
        preview.delegate = self
        self.present(preview, animated: true, completion: nil)
    }
    
    public func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }
    
    public func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        //  pass your document url here
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        
        let path = dir?.appendingPathComponent("Чек_\(checkDate).pdf")
        return path as! QLPreviewItem
    }
    
    //отправка чека по e-mail
    func sendByEmail() {
        if !MFMailComposeViewController.canSendMail() {
            print ("Mail services are not available")
            return
        }
        
        let mailVC = MFMailComposeViewController()
        mailVC.mailComposeDelegate = self
        
        let text = self.createHTML()
        
        mailVC.setToRecipients([UserDefaults.standard.string(forKey: "email")!])
        mailVC.setSubject("")
        mailVC.setMessageBody(text, isHTML: true)
        
        self.present(mailVC, animated: true, completion: nil)
    }
    
    func createMessageBody(text: String) {
        let file = "html.txt"
        
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(file)
            
            do {
                try text.write(to: fileURL, atomically: false, encoding: .utf8)
                print ("file created")
            } catch {
                print ("error while writing the file: \(error.localizedDescription)")
            }
        }
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        print ("mail sent")
        
        controller.dismiss(animated: true, completion: nil)
    }
    
    //сохранение чека
    func saveTheCheck() {
        //создаем новый массив и копируем туда наш чек
        var itemsToRealm: [CheckInfoObject] = []
        
        for section in items {
            for item in section {
                let copyItem = item.copyItem()
                itemsToRealm.append(copyItem)
            }
        }
        //удаляем старый чек, записываем в realm новый массив
        do {
            let realm = try Realm()
            realm.beginWrite()
            //            parentString.checkItems.removeAll()
            let oldCheck = realm.objects(CheckInfoObject.self).filter("%@ IN parent", parentString).sorted(byKeyPath: "sectionId")
            realm.delete(oldCheck)
            for item in itemsToRealm {
                parentString.checkItems.append(item)
            }
            try realm.commitWrite()
        } catch {
            print(error)
        }
        print ("check saved")
    }

}
