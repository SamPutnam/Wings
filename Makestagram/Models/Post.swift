
//
//  Post.swift
//  Makestagram
//
//  Created by Samuel Putnam on 6/30/16.
//  Copyright © 2016 Make School. All rights reserved.
//

import UIKit
import Foundation
import Parse
import Bond
import ConvenienceKit

class Post: PFObject, PFSubclassing {

    @NSManaged var caption : String
    var image : Observable<UIImage?> = Observable(nil)
    var likes : Observable<[PFUser]?> = Observable(nil)
    var photoUploadTask : UIBackgroundTaskIdentifier?
    static var imageCache : NSCacheSwift<String, UIImage>!
    @NSManaged var imageFile: PFFile!
    @NSManaged var user: PFUser!
    
    //MARK: PFSubclassing Protocol
    
    static func parseClassName() -> String {
        return "Post"
    }
    
    override init(){
    super.init()
    }
    
    override class func initialize() {
        var onceToken : dispatch_once_t = 0;
        dispatch_once(&onceToken) {
            // inform Parse about this subclass
            self.registerSubclass()
            Post.imageCache = NSCacheSwift<String, UIImage>()
        }
    }
    
    func uploadPost() {
        if let image = image.value {
            guard let imageData = UIImageJPEGRepresentation(image, 0.8) else {return}
            guard let imageFile = PFFile(name: "image.jpg", data: imageData) else {return}
            // any uploaded post should be associated with the current user
            user = PFUser.currentUser()
            self.imageFile = imageFile
            photoUploadTask = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler { () -> Void in
                UIApplication.sharedApplication().endBackgroundTask(self.photoUploadTask!)
            }
            saveInBackgroundWithBlock { (success: Bool, error: NSError?) in
                if let error = error {
                    ErrorHandling.defaultErrorHandler(error)
                }
                UIApplication.sharedApplication().endBackgroundTask(self.photoUploadTask!)
            }
        }
    }
    
    func downloadImage() {
        image.value = Post.imageCache[self.imageFile!.name]
        //if image is not downloaded yet, get it
        if (image.value  == nil) {
            imageFile?.getDataInBackgroundWithBlock { (data: NSData?, error: NSError?) -> Void in
            if let error = error {
                    ErrorHandling.defaultErrorHandler(error)
            }
            if let data = data {
                let image = UIImage(data: data, scale: 1.0)!
                self.image.value = image
                Post.imageCache[self.imageFile!.name] = image
            }
            }
        }
    }
    
    func fetchLikes() {
        if (likes.value != nil) {
            return
        }
        
        ParseHelper.likesForPosts(self, completionBlock: { (likes: [PFObject]?, error: NSError?) -> Void in
            if let error = error {
                ErrorHandling.defaultErrorHandler(error)
            }
            let validLikes = likes?.filter { like in like[ParseHelper.ParseLikeFromUser] != nil }
            
            self.likes.value = validLikes?.map { like in
                let fromUser = like[ParseHelper.ParseLikeFromUser] as! PFUser
                
                return fromUser
            }
        })
    }
    
    func doesUserLikePost(user: PFUser) -> Bool {
        if let likes  = likes.value {
            return likes.contains(user)
        } else {
            return false
        }
    }
    func toggleLikePost(user: PFUser) {
        if (doesUserLikePost(user)) {
            // if the post is liked, unlike it now
            likes.value = likes.value?.filter { $0 != user }
            ParseHelper.unlikePost(user, post: self)
        } else {
            // if this post is not liked yet, like it now
            likes.value?.append(user)
            ParseHelper.likePost(user, post: self)
        }
    }
    // MARK: Flagging
    
    func flagPost(user: PFUser) {
        ParseHelper.flagPost(user, post: self)
    }

}